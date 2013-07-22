-- Metadata information about system functions
--
-- Functions NOT registered in this table are considered
-- to be IMMUTABLE (ie: independent on database state)
--
-- STABLE/VOLATILE functions should be registered here
-- to advertise the list of tables they could possibly
-- fetch data from and write data to.
--
CREATE TABLE IF NOT EXISTS
  public.CDB_FunctionMetadata (
    id serial NOT NULL PRIMARY KEY, -- for easy editing, if needed
    pattern text NOT NULL UNIQUE, -- regexp pattern
    read text, -- schema-less, comma-separated, backreferences allowed
    write text, -- schema-less, comma-separated, backreferences allowed
    -- The function either reads or writes to the db,
    -- ot it shouldn't be registered here
    CONSTRAINT "either_writes_or_reads" CHECK (
      read is not null or write is not null
    )
  );

GRANT SELECT ON public.CDB_FunctionMetadata TO public;
