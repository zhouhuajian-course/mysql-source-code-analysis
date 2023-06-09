--source include/have_ndb.inc

--let $dump_file= $MYSQLTEST_VARDIR/tmp/restore_out.txt


--disable_query_log
create table test.ndb_restore_output(line varchar(1000))
  engine=Innodb;
eval load data infile '$dump_file' into table test.ndb_restore_output;

# remove <CR> from line in Windows
update test.ndb_restore_output set line = trim(trailing '\r' from line);

# Masking timestamp from the restore output with 'X' to avoid tests
# running on different dates give 'Result content mismatch'.
--replace_regex /[0-9]*-[0-9]*-[0-9]* [0-9]*:[0-9]*:[0-9]*/XXXX-XX-XX XX:XX:XX/
select line as "row" from test.ndb_restore_output
  where line like "%WARNING%" order by line;

drop table test.ndb_restore_output;
--enable_query_log
