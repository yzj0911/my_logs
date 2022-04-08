# Dblink




# Dblink


查询所有触发器
```sql
select * from user_triggers;
```
根据名称禁用触发器
```sql
alter trigger LOGMNRGGC_TRIGGER disable;
```
查询所有 job
```sql
select * from user_jobs;
```
根据 id 禁用 job
```sql
BEGIN dbms_job.broken(4001,true); END;
```

禁用 oracle dblink
```sql
alter system set open_links=0 sid='$sid' scope=spfile;
alter system set open_links_per_instance=0 sid='$sid' scope=spfile;
```

启用 oracle dblink
```sql
alter system set open_links=4 sid='$sid' scope=spfile;
alter system set open_links_per_instance=4 sid='$sid' scope=spfile;
```

