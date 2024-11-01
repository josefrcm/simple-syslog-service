create extension if not exists timescaledb;

-------------------------------------------------------------------------------------
-- Reference tables from RFC5424
-------------------------------------------------------------------------------------

create table ref_facility(
	facility_id int primary key,
	name text not null unique,
	description text not null
);

insert into ref_facility values(0, 'kern', 'Kernel messages');
insert into ref_facility values(1, 'user', 'User-level messages');
insert into ref_facility values(2, 'mail', 'Mail system');
insert into ref_facility values(3, 'daemon', 'System daemons');
insert into ref_facility values(4, 'auth', 'Security/authentication messages');
insert into ref_facility values(5, 'syslog', 'Messages generated internally by syslogd');
insert into ref_facility values(6, 'lpr', 'Line printer subsystem');
insert into ref_facility values(7, 'news', 'Network news subsystem');
insert into ref_facility values(8, 'uucp', 'UUCP subsystem');
insert into ref_facility values(9, 'cron', 'Cron subsystem');
insert into ref_facility values(10, 'authpriv', 'Security/authentication messages');
insert into ref_facility values(11, 'ftp', 'FTP daemon');
insert into ref_facility values(12, 'ntp', 'NTP subsystem');
insert into ref_facility values(13, 'security', 'Log audit');
insert into ref_facility values(14, 'console', 'Log alert');
insert into ref_facility values(15, 'solaris-cron', 'Scheduling daemon');
insert into ref_facility values(16, 'local0', 'Locally used facilities');
insert into ref_facility values(17, 'local1', 'Locally used facilities');
insert into ref_facility values(18, 'local2', 'Locally used facilities');
insert into ref_facility values(19, 'local3', 'Locally used facilities');
insert into ref_facility values(20, 'local4', 'Locally used facilities');
insert into ref_facility values(21, 'local5', 'Locally used facilities'); 
insert into ref_facility values(22, 'local6', 'Locally used facilities');
insert into ref_facility values(23, 'local7', 'Locally used facilities');

create table ref_severity(
	severity_id int primary key,
	name text not null unique,
	description text not null
);

insert into ref_severity values(0, 'Emergency', 'System is unusable');
insert into ref_severity values(1, 'Alert', 'Action must be taken immediately');
insert into ref_severity values(2, 'Critical', 'Critical conditions');
insert into ref_severity values(3, 'Error', 'Error conditions');
insert into ref_severity values(4, 'Warning', 'Warning conditions');
insert into ref_severity values(5, 'Notice', 'Normal but significant condition');
insert into ref_severity values(6, 'Informational', 'Informational messages');
insert into ref_severity values(7, 'Debug', 'Debug-level messages');

-------------------------------------------------------------------------------------
-- Messages
-------------------------------------------------------------------------------------

create table messages(
	host text not null,
	host_time timestamp with time zone not null,
	server_time timestamp with time zone not null,
	facility_id int not null,
	severity_id int not null,
	program text,
	message text
);

create index messages_main_idx on messages(host, host_time);

select create_hypertable(
	'messages',
	by_range('host_time', interval '1 day'),
	create_default_indexes => false,
	migrate_data => true
);

alter table messages set (
	timescaledb.compress,
	timescaledb.compress_orderby = 'host_time',
	timescaledb.compress_segmentby = 'host'
);

select add_compression_policy(
	'messages',
	compress_after => INTERVAL '2 days'
);

-------------------------------------------------------------------------------------
-- Additional views to speed up the queries
-- This part should be improved, for example by using pg_ivm
-------------------------------------------------------------------------------------

create materialized view programs as select distinct host, program from messages order by host, program;

create view hosts as select distinct host from programs order by host;

create or replace procedure refresh_programs(job_id int, config jsonb) language PLPGSQL as
$$
begin
	refresh materialized view programs;
end
$$;

select add_job('refresh_programs', '1h');
