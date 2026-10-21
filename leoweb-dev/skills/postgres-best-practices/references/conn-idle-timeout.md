---
title: Configurer les timeouts des connexions inactives
impact: HIGH
impactDescription: Reclaim 30-50% of connection slots from idle clients
tags: connections, timeout, idle, resource-management
---

## Configurer les timeouts des connexions inactives

Les connexions inactives gaspillent des ressources. Configure des timeouts pour les récupérer automatiquement.

**Incorrect (connexions conservées indéfiniment) :**

```sql
-- No timeout configured
show idle_in_transaction_session_timeout;  -- 0 (disabled)

-- Connections stay open forever, even when idle
select pid, state, state_change, query
from pg_stat_activity
where state = 'idle in transaction';
-- Shows transactions idle for hours, holding locks
```

**Correct (nettoyage automatique des connexions inactives) :**

```sql
-- Terminate connections idle in transaction after 30 seconds
alter system set idle_in_transaction_session_timeout = '30s';

-- Terminate completely idle connections after 10 minutes
alter system set idle_session_timeout = '10min';

-- Reload configuration
select pg_reload_conf();
```

Pour les connexions poolées, configure au niveau du pooler :

```ini
# pgbouncer.ini
server_idle_timeout = 60
client_idle_timeout = 300
```

Reference: [Connection Timeouts](https://www.postgresql.org/docs/current/runtime-config-client.html#GUC-IDLE-IN-TRANSACTION-SESSION-TIMEOUT)
