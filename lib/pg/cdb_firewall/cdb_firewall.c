/*-------------------------------------------------------------------------
 *
 * query_firewall.c
 *
 *
 * Copyright (c) 2013, Sandro Santilli <strk@keybit.net>
 *
 *
 * Adapted from pg_stat_statements.c
 *
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include <limits.h>

#include "commands/explain.h"
#include "executor/instrument.h"
#include "utils/guc.h"
#include "tcop/utility.h"
#include "miscadmin.h"

PG_MODULE_MAGIC;

/*---- Local variables ----*/

/* Saved hook values in case of unload */
static ProcessUtility_hook_type prev_ProcessUtility = NULL;

#define firewall_enabled() \
  ( ! superuser() )

/*---- Function declarations ----*/

void            _PG_init(void);
void            _PG_fini(void);

static void firewall_ProcessUtility(Node *parsetree,
			  const char *queryString, ParamListInfo params, bool isTopLevel,
					DestReceiver *dest, char *completionTag);

/*
 * Module load callback
 */
void
_PG_init(void)
{
  //ereport(LOG, (errmsg("query_firewall loaded"), errhidestmt(true)));

  /* Install hooks. */
  prev_ProcessUtility = ProcessUtility_hook;
  ProcessUtility_hook = firewall_ProcessUtility;

}

/*
 * Module unload callback
 */
void
_PG_fini(void)
{
  //ereport(LOG, (errmsg("query_firewall unloaded"), errhidestmt(true)));
  /* Uninstall hooks. */
  ProcessUtility_hook = prev_ProcessUtility;
}

/*
 * ProcessUtility hook
 */
static void
firewall_ProcessUtility(Node *parsetree, const char *queryString,
					ParamListInfo params, bool isTopLevel,
					DestReceiver *dest, char *completionTag)
{

#ifdef QUERY_FIREWALL_DEBUG
  ereport(LOG, (errmsg("ProcessUtility, isTopLevel:%d, queryString='%s' completionTag:%s, nodeTag(parsetree):%d", isTopLevel, queryString, completionTag, nodeTag(parsetree)), errhidestmt(true)));

  ereport(LOG, (errmsg(" T_VariableSetStmt is %d", T_VariableSetStmt), errhidestmt(true)));
  ereport(LOG, (errmsg(" T_AlterTableStmt is %d", T_AlterTableStmt), errhidestmt(true)));
  ereport(LOG, (errmsg(" T_AlterTableCmd is %d", T_AlterTableCmd), errhidestmt(true)));
  ereport(LOG, (errmsg(" T_CreateStmt is %d", T_CreateStmt), errhidestmt(true)));
  ereport(LOG, (errmsg(" T_DropStmt is %d", T_DropStmt), errhidestmt(true)));
  ereport(LOG, (errmsg(" T_TruncateStmt is %d", T_TruncateStmt), errhidestmt(true)));
#endif

	if (firewall_enabled())
	{
    if ( nodeTag(parsetree) == T_VariableSetStmt ) {
      ereport(LOG, (errmsg(" About to forbid statement '%s'", queryString), errhidestmt(false)));
      ereport(ERROR, (errmsg("Using SET is forbidden for non-superusers"), errhidestmt(false)));
      errdetail("Non-superusers must provide a password in the connection string.");
    }
	else if ( nodeTag(parsetree) == T_VariableShowStmt ) {
      ereport(LOG, (errmsg(" About to forbid statement '%s'", queryString), errhidestmt(false)));
      ereport(ERROR, (errmsg("Using SHOW is forbidden for non-superusers"), errhidestmt(false)));
      errdetail("Non-superusers must provide a password in the connection string.");
    }

	}

  if (prev_ProcessUtility)
    prev_ProcessUtility(parsetree, queryString, params,
              isTopLevel, dest, completionTag);
  else
    standard_ProcessUtility(parsetree, queryString, params,
                isTopLevel, dest, completionTag);
}
