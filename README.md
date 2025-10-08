# pg-drip
Postgres Distributed Replica in Patroni (containerized)

```
██████╗  ██████╗     ██████╗ ██████╗ ██╗██████╗        ██╗
██╔══██╗██╔════╝     ██╔══██╗██╔══██╗██║██╔══██╗      ████╗
██████╔╝██║  ███╗    ██║  ██║██████╔╝██║██████╔╝     ██████╗
██╔═══╝ ██║   ██║    ██║  ██║██╔══██╗██║██╔═══╝     ████████╗
██║     ╚██████╔╝    ██████╔╝██║  ██║██║██║         ████████║
╚═╝      ╚═════╝     ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝          ██████║
   P o s t g r e s   D i s t r i b u t e d            ████║
     R e p l i c a   i n   P a t r o n i               ██║
       ( C o n t a i n e r i z e d )                   ╚╝
```
![pg-drip Status](https://img.shields.io/badge/PG_DRIP-PASSING-green?style=flat-square&logo=cloudflare)
![Budget](https://img.shields.io/badge/Budget-$5%2Fmo-orange?style=flat-square&logo=money)
![Uptime](https://img.shields.io/badge/Uptime-99.9%25-yellow?style=flat-square)
![Vibes](https://img.shields.io/badge/Vibes-Unhinged-ff69b4?style=flat-square)
![Failover](https://img.shields.io/badge/Failover-Sorta_Working-blueviolet?style=flat-square)
---

# pg-drip  

> Forget boring old single-node databases. With **pg-drip**, your Postgres comes with **high availability** and **leader election** — with **Patroni** + **Consul**. 

---


## ✨ Features (the flex)  
- 🚰 **HA Postgres**: Automatic failover with Patroni.
- 🧑‍🤝‍🧑 **Clustered Consul**: Gossip harder than group chats.
- 🚢 **Kamal ready**: One accessory, multiple hosts — instant prod drip.
- 🕶️ **Self-healing**: Lose a node? Still runs until you get back from your golf trip
- 🚀 **Cloud-agnostic**: Run it on DigitalOcean, Hetzner, AWS, bare metal, or your own basement server.

## 🐳 Try it out in Docker Compose

### 1. Clone this repo  
```bash
git clone https://github.com/your-org/pg-drip.git
cd pg-drip
```

### 2. Spin up the cluster
```bash
docker compose up -d --build
```

### What's going on?

	•	Three containers (pgdrip1, pgdrip2, pgdrip3) boot up.
	•	Consul gossips them into a single cluster.
	•	Patroni elects a leader.
	•	Postgres starts serving iced-out SQL.

### 3. Connect to your database
```bash
psql -h localhost -p 5433 -U postgres
```

## 🚀 Running in Kamal
So you’re serious now huh? 👀 Time to deploy pg-drip in the wild.
### 1. Add an accessory to your kamal deploy.yaml
```yaml
# deploy.yml
accessories:
  pg-drip:
    service: pg-drip
    image: ghcr.io/classifieddotdev/pg-drip:latest
    hosts:
      - host1
      - host2
      - host3
    env:
      clear:
        CONSUL_EXPECT: 3                 # 3 nodes is recommended for High Availibility
        CONSUL_JOIN: host1               # Bootstrap gossip on host1
      secret:
        - POSTGRES_USER                  # Define these in .kamal/secrets
        - POSTGRES_PASSWORD
        - REPLICATION_PASSWORD
    host_vars:
      host1:
        env:
          clear:
            PATRONI_NAME: "pgdrip1"
      host2:
        env:
          clear:
            PATRONI_NAME: "pgdrip2"
      host3:
        env:
          clear:
            PATRONI_NAME: "pgdrip3"
    directories:
      - /var/lib/postgresql/patroni
      - /var/lib/consul
    ports:
      - "5432:5432"
      - "8008:8008"
      - "8500:8500"
```

### 2. Update .kamal/secrets
```
# Add these variables
POSTGRES_USER=$SomeUser
POSTGRES_PASSWORD=$SomePassword
REPLICATION_PASSWORD=$TopSecretDoNotSharePls
```

### 3. Boot the accessory
```bash
kamal accessory boot pg-drip
```

--- 
## Troubleshooting

1. Sometimes when the initial cluster is started, a random node is selected as the leader, you can mitigate this by starting each node individually

#### docker compose
```bash
docker compose -f 'compose.yaml' up -d --build 'pgdrip1' 
docker compose -f 'compose.yaml' up -d --build 'pgdrip2' 
docker compose -f 'compose.yaml' up -d --build 'pgdrip3' 
```

#### Kamal
```bash
kamal accessory boot pg-drip --hosts=host1
kamal accessory boot pg-drip --hosts=host2
kamal accessory boot pg-drip --hosts=host3
```

2. To check the status of a cluster, you can use patronictl **list**

#### docker compose
```bash
docker exec <containerID> patronictl list
```

#### kamal
```bash
kamal accessory exec --hosts=host1 patronictl list
```

3. To manually switchover a cluster, you can use patronictl **switchover**

#### docker compose
```bash
docker exec <containerID> patronictl switchover pg-drip --candidate host3
```

#### kamal
```bash
kamal accessory exec --hosts=host1 patronictl switchover pg-drip --candidate host3
```

## Warning: Only run patroni commands on 1 host at a time.