create or replace function public.nest() returns void as $$
BEGIN
  EXECUTE 's' || 'et statement_tim' || 'eout = 100';
END
$$ language 'plpgsql';

create or replace function public.nest2() returns void as $$
BEGIN
  perform nest();
END; $$ language 'plpgsql';

load 'cdb_firewall';

select nest2();
RESET statement_timeout; -- reset

set session authorization guest;

select nest2();
-- can't RESET (same as can't SET)
reset session authorization;

SELECT setseed(0.2); -- this is still allowed
