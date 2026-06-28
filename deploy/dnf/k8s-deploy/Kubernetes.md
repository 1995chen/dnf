# Kubernetes 部署DNF

> 注意：Kubernetes 的 `volumeMounts` 不支持 Docker `-v` / Docker Compose 那种 `:Z` 挂载语法。
>
> 因此，Docker / Docker Compose 部署可以通过 `:Z` 兼容 SELinux，而 Kubernetes 部署需要依赖集群自身的存储类型、节点 SELinux 策略或 Pod `securityContext` 做适配；本项目文档不再要求为了部署 DNF 而全局关闭宿主机 SELinux。


## 创建

在集群里安装nfs provider, 后期挂载数据用, /root/nfs/data在每个节点提前创建
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=<你的NFS Server的IP> \
    --set nfs.path=/root/nfs/data
```

## 创建命名空间

```bash
kubectl create namespace dnf-server
```

## 创建PVC

这里把所有的数据都放到一个pvc下,通过subpath分区

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dnf
  namespace: dnf-server
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10G
EOF
```

## 创建配置和密钥

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: dnf
  namespace: dnf-server
data:
  gm_lander_version: "20180307"

---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: dnf
  namespace: dnf-server
data:
  mysql_root_password: ODg4ODg4ODg=
  gm_account: Z21hZG1pbg==
  gm_password: MjAyNDA1MzE=
  gm_connect_key: UERNS1hOUUlXTTlJUjEyOEVNWE0=
EOF
```

## 创建Mysql

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf-mysql
  namespace: dnf-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf-mysql
  template:
    metadata:
      labels:
        app: dnf-mysql
    spec:
      restartPolicy: Always
      volumes:
      - name: dnf
        persistentVolumeClaim:
          claimName: dnf
      containers:
      - name: mysql
        imagePullPolicy: IfNotPresent
        image: 1995chen/mysql:5.0.95
        ports:
        - name: mysql
          containerPort: 3306
          protocol: TCP
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "1024Mi"
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: DNF_DB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: mysql_root_password
              name: dnf
        volumeMounts:
        - mountPath: /var/lib/mysql
          name: dnf
          subPath: mysql
---
apiVersion: v1
kind: Service
metadata:
  name: dnf-mysql
  namespace: dnf-server
  labels:
    app: dnf-mysql
spec:
  ports:
    - name: mysql-port
      port: 3306
      targetPort: 3306
  selector:
    app: dnf-mysql
EOF
```

## 创建DNF CORE服务

```bash
# 创建dnf-cain-core/dnf-diregie-core/dnf-siroco-core的Service
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: dnf-cain-core
  namespace: dnf-server
  labels:
    app: dnf-cain-core
spec:
  ports:
    - name: channel-tcp
      port: 7001
      protocol: TCP
    - name: channel-udp
      port: 7001
      protocol: UDP
    - name: gate-login
      port: 7600
      protocol: TCP
    - name: gate-admin
      port: 881
      protocol: TCP
    - name: bridge-tcp
      port: 7000
      protocol: TCP
    - name: bridge-udp
      port: 7000
      protocol: UDP
    - name: monitor-tcp
      port: 31303
      protocol: TCP
    - name: monitor-udp
      port: 31303
      protocol: UDP
    - name: guild-tcp
      port: 31403
      protocol: TCP
    - name: guild-udp
      port: 31403
      protocol: UDP
    - name: statistic
      port: 31503
      protocol: UDP
    - name: point-tcp
      port: 31603
      protocol: TCP
    - name: point-udp
      port: 31603
      protocol: UDP
    - name: coserver
      port: 31703
      protocol: UDP
    - name: auction-tcp
      port: 31803
      protocol: TCP
    - name: auction-udp
      port: 31803
      protocol: UDP
    - name: community-tcp
      port: 31100
      protocol: TCP
    - name: community-udp
      port: 31100
      protocol: UDP
    - name: relay-config
      port: 5001
      protocol: TCP
  selector:
    app: dnf-cain-core
---
# 这里注意只有主大区需要7000-7001端口,狄瑞吉和希洛会使用主大区的7000-7001
apiVersion: v1
kind: Service
metadata:
  name: dnf-diregie-core
  namespace: dnf-server
  labels:
    app: dnf-diregie-core
spec:
  ports:
    - name: monitor-tcp
      port: 32303
      protocol: TCP
    - name: monitor-udp
      port: 32303
      protocol: UDP
    - name: guild-tcp
      port: 32403
      protocol: TCP
    - name: guild-udp
      port: 32403
      protocol: UDP
    - name: statistic
      port: 32503
      protocol: UDP
    - name: point-tcp
      port: 32603
      protocol: TCP
    - name: point-udp
      port: 32603
      protocol: UDP
    - name: coserver
      port: 32703
      protocol: UDP
    - name: auction-tcp
      port: 32803
      protocol: TCP
    - name: auction-udp
      port: 32803
      protocol: UDP
    - name: community-tcp
      port: 32100
      protocol: TCP
    - name: community-udp
      port: 32100
      protocol: UDP
    - name: relay-config
      port: 5002
      protocol: TCP
  selector:
    app: dnf-diregie-core
---
apiVersion: v1
kind: Service
metadata:
  name: dnf-siroco-core
  namespace: dnf-server
  labels:
    app: dnf-siroco-core
spec:
  ports:
    - name: monitor-tcp
      port: 33303
      protocol: TCP
    - name: monitor-udp
      port: 33303
      protocol: UDP
    - name: guild-tcp
      port: 33403
      protocol: TCP
    - name: guild-udp
      port: 33403
      protocol: UDP
    - name: statistic
      port: 33503
      protocol: UDP
    - name: point-tcp
      port: 33603
      protocol: TCP
    - name: point-udp
      port: 33603
      protocol: UDP
    - name: coserver
      port: 33703
      protocol: UDP
    - name: auction-tcp
      port: 33803
      protocol: TCP
    - name: auction-udp
      port: 33803
      protocol: UDP
    - name: community-tcp
      port: 33100
      protocol: TCP
    - name: community-udp
      port: 33100
      protocol: UDP
    - name: relay-config
      port: 5003
      protocol: TCP
  selector:
    app: dnf-siroco-core
EOF

# 创建dnf-cain-core
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf-cain-core
  namespace: dnf-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf-cain-core
  template:
    metadata:
      labels:
        app: dnf-cain-core
    spec:
      restartPolicy: Always
      volumes:
      - name: dnf
        persistentVolumeClaim:
          claimName: dnf
      containers:
      - name: dnf
        imagePullPolicy: IfNotPresent
        image: 1995chen/dnf:centos5-a8dec7b
        ports:
        - name: channel-tcp
          containerPort: 7001
          protocol: TCP
        - name: channel-udp
          containerPort: 7001
          protocol: UDP
        - name: gate-login
          containerPort: 7600
          protocol: TCP
        - name: gate-admin
          containerPort: 881
          protocol: TCP
        - name: bridge-tcp
          containerPort: 7000
          protocol: TCP
        - name: bridge-udp
          containerPort: 7000
          protocol: UDP
        - name: monitor-tcp
          containerPort: 31303
          protocol: TCP
        - name: monitor-udp
          containerPort: 31303
          protocol: UDP
        - name: guild-tcp
          containerPort: 31403
          protocol: TCP
        - name: guild-udp
          containerPort: 31403
          protocol: UDP
        - name: statistic
          containerPort: 31503
          protocol: UDP
        - name: point-tcp
          containerPort: 31603
          protocol: TCP
        - name: point-udp
          containerPort: 31603
          protocol: UDP
        - name: coserver
          containerPort: 31703
          protocol: UDP
        - name: auction-tcp
          containerPort: 31803
          protocol: TCP
        - name: auction-udp
          containerPort: 31803
          protocol: UDP
        - name: community-tcp
          containerPort: 31100
          protocol: TCP
        - name: community-udp
          containerPort: 31100
          protocol: UDP
        - name: relay-config
          containerPort: 5001
          protocol: TCP
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "800m"
            memory: "512Mi"
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: SERVER_TYPE
          value: CORE
        - name: SERVER_GROUP
          value: "1"
        - name: SERVER_GROUP_DB
          value: cain
        - name: MAIN_MYSQL_GAME_ALLOW_IP
          value: "10.244.%"
        - name: MYSQL_GAME_ALLOW_IP
          value: "10.244.%"
        - name: MAIN_MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MAIN_MYSQL_PORT
          value: "3306"
        - name: MAIN_MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: mysql_root_password
              name: dnf
        - name: MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MYSQL_PORT
          value: "3306"
        # 这里可以使用dnf-cain-core的ServiceIP
        - name: PUBLIC_IP
          value: dnf-cain-core.dnf-server.svc.cluster.local
        - name: DNF_DB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: mysql_root_password
              name: dnf
        - name: GM_ACCOUNT
          valueFrom:
            secretKeyRef:
              key: gm_account
              name: dnf
        - name: GM_PASSWORD
          valueFrom:
            secretKeyRef:
              key: gm_password
              name: dnf
        - name: GM_LANDER_VERSION
          valueFrom:
            configMapKeyRef:
              key: gm_lander_version
              name: dnf
        - name: GM_CONNECT_KEY
          valueFrom:
            secretKeyRef:
              key: gm_connect_key
              name: dnf
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data_cain_core
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf-diregie-core
  namespace: dnf-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf-diregie-core
  template:
    metadata:
      labels:
        app: dnf-diregie-core
    spec:
      restartPolicy: Always
      volumes:
      - name: dnf
        persistentVolumeClaim:
          claimName: dnf
      containers:
      - name: dnf
        imagePullPolicy: IfNotPresent
        image: 1995chen/dnf:centos5-a8dec7b
        ports:
        - name: monitor-tcp
          containerPort: 32303
          protocol: TCP
        - name: monitor-udp
          containerPort: 32303
          protocol: UDP
        - name: guild-tcp
          containerPort: 32403
          protocol: TCP
        - name: guild-udp
          containerPort: 32403
          protocol: UDP
        - name: statistic
          containerPort: 32503
          protocol: UDP
        - name: point-tcp
          containerPort: 32603
          protocol: TCP
        - name: point-udp
          containerPort: 32603
          protocol: UDP
        - name: coserver
          containerPort: 32703
          protocol: UDP
        - name: auction-tcp
          containerPort: 32803
          protocol: TCP
        - name: auction-udp
          containerPort: 32803
          protocol: UDP
        - name: community-tcp
          containerPort: 32100
          protocol: TCP
        - name: community-udp
          containerPort: 32100
          protocol: UDP
        - name: relay-config
          containerPort: 5002
          protocol: TCP
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "800m"
            memory: "512Mi"
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: SERVER_TYPE
          value: CORE
        # 这里填写dnf-cain-core的ServiceIP
        - name: MAIN_BRIDGE_IP
          value: dnf-cain-core.dnf-server.svc.cluster.local
        - name: SERVER_GROUP
          value: "2"
        - name: SERVER_GROUP_DB
          value: diregie
        - name: MAIN_MYSQL_GAME_ALLOW_IP
          value: "10.244.%"
        - name: MYSQL_GAME_ALLOW_IP
          value: "10.244.%"
        - name: MAIN_MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MAIN_MYSQL_PORT
          value: "3306"
        - name: MAIN_MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: mysql_root_password
              name: dnf
        - name: MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MYSQL_PORT
          value: "3306"
        # 这里可以使用dnf-diregie-core的ServiceIP
        - name: PUBLIC_IP
          value: dnf-diregie-core.dnf-server.svc.cluster.local
        - name: DNF_DB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: mysql_root_password
              name: dnf
        - name: GM_ACCOUNT
          valueFrom:
            secretKeyRef:
              key: gm_account
              name: dnf
        - name: GM_PASSWORD
          valueFrom:
            secretKeyRef:
              key: gm_password
              name: dnf
        - name: GM_LANDER_VERSION
          valueFrom:
            configMapKeyRef:
              key: gm_lander_version
              name: dnf
        - name: GM_CONNECT_KEY
          valueFrom:
            secretKeyRef:
              key: gm_connect_key
              name: dnf
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data_diregie_core
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf-siroco-core
  namespace: dnf-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf-siroco-core
  template:
    metadata:
      labels:
        app: dnf-siroco-core
    spec:
      restartPolicy: Always
      volumes:
      - name: dnf
        persistentVolumeClaim:
          claimName: dnf
      containers:
      - name: dnf
        imagePullPolicy: IfNotPresent
        image: 1995chen/dnf:centos5-a8dec7b
        ports:
        - name: monitor-tcp
          containerPort: 33303
          protocol: TCP
        - name: monitor-udp
          containerPort: 33303
          protocol: UDP
        - name: guild-tcp
          containerPort: 33403
          protocol: TCP
        - name: guild-udp
          containerPort: 33403
          protocol: UDP
        - name: statistic
          containerPort: 33503
          protocol: UDP
        - name: point-tcp
          containerPort: 33603
          protocol: TCP
        - name: point-udp
          containerPort: 33603
          protocol: UDP
        - name: coserver
          containerPort: 33703
          protocol: UDP
        - name: auction-tcp
          containerPort: 33803
          protocol: TCP
        - name: auction-udp
          containerPort: 33803
          protocol: UDP
        - name: community-tcp
          containerPort: 33100
          protocol: TCP
        - name: community-udp
          containerPort: 33100
          protocol: UDP
        - name: relay-config
          containerPort: 5003
          protocol: TCP
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "800m"
            memory: "512Mi"
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: SERVER_TYPE
          value: CORE
        # 这里填写dnf-cain-core的ServiceIP
        - name: MAIN_BRIDGE_IP
          value: dnf-cain-core.dnf-server.svc.cluster.local
        - name: SERVER_GROUP
          value: "3"
        - name: SERVER_GROUP_DB
          value: siroco
        - name: MAIN_MYSQL_GAME_ALLOW_IP
          value: "10.244.%"
        - name: MYSQL_GAME_ALLOW_IP
          value: "10.244.%"
        - name: MAIN_MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MAIN_MYSQL_PORT
          value: "3306"
        - name: MAIN_MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: mysql_root_password
              name: dnf
        - name: MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MYSQL_PORT
          value: "3306"
        # 这里可以使用dnf-siroco-core的ServiceIP
        - name: PUBLIC_IP
          value: dnf-siroco-core.dnf-server.svc.cluster.local
        - name: DNF_DB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: mysql_root_password
              name: dnf
        - name: GM_ACCOUNT
          valueFrom:
            secretKeyRef:
              key: gm_account
              name: dnf
        - name: GM_PASSWORD
          valueFrom:
            secretKeyRef:
              key: gm_password
              name: dnf
        - name: GM_LANDER_VERSION
          valueFrom:
            configMapKeyRef:
              key: gm_lander_version
              name: dnf
        - name: GM_CONNECT_KEY
          valueFrom:
            secretKeyRef:
              key: gm_connect_key
              name: dnf
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data_siroco_core
EOF
```

## 创建DNF P2P服务

```bash
# 创建P2P Service
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: dnf-cain-p2p
  namespace: dnf-server
  labels:
    app: dnf-cain-p2p
spec:
  ports:
    - name: relay-tcp
      port: 7100
      protocol: TCP
    - name: relay-udp
      port: 7100
      protocol: UDP
    - name: stun-tcp-01
      port: 2111
      protocol: TCP
    - name: stun-udp-01
      port: 2111
      protocol: UDP
    - name: stun-tcp-02
      port: 2112
      protocol: TCP
    - name: stun-udp-02
      port: 2112
      protocol: UDP
    - name: stun-tcp-03
      port: 2113
      protocol: TCP
    - name: stun-udp-03
      port: 2113
      protocol: UDP
  selector:
    app: dnf-cain-p2p
---
apiVersion: v1
kind: Service
metadata:
  name: dnf-diregie-p2p
  namespace: dnf-server
  labels:
    app: dnf-diregie-p2p
spec:
  ports:
    - name: relay-tcp
      port: 7200
      protocol: TCP
    - name: relay-udp
      port: 7200
      protocol: UDP
    - name: stun-tcp-01
      port: 2211
      protocol: TCP
    - name: stun-udp-01
      port: 2211
      protocol: UDP
    - name: stun-tcp-02
      port: 2212
      protocol: TCP
    - name: stun-udp-02
      port: 2212
      protocol: UDP
    - name: stun-tcp-03
      port: 2213
      protocol: TCP
    - name: stun-udp-03
      port: 2213
      protocol: UDP
  selector:
    app: dnf-diregie-p2p
---
apiVersion: v1
kind: Service
metadata:
  name: dnf-siroco-p2p
  namespace: dnf-server
  labels:
    app: dnf-siroco-p2p
spec:
  ports:
    - name: relay-tcp
      port: 7300
      protocol: TCP
    - name: relay-udp
      port: 7300
      protocol: UDP
    - name: stun-tcp-01
      port: 2311
      protocol: TCP
    - name: stun-udp-01
      port: 2311
      protocol: UDP
    - name: stun-tcp-02
      port: 2312
      protocol: TCP
    - name: stun-udp-02
      port: 2312
      protocol: UDP
    - name: stun-tcp-03
      port: 2313
      protocol: TCP
    - name: stun-udp-03
      port: 2313
      protocol: UDP
  selector:
    app: dnf-siroco-p2p
EOF

# 创建P2P服务
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf-cain-p2p
  namespace: dnf-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf-cain-p2p
  template:
    metadata:
      labels:
        app: dnf-cain-p2p
    spec:
      restartPolicy: Always
      volumes:
      - name: dnf
        persistentVolumeClaim:
          claimName: dnf
      containers:
      - name: dnf
        imagePullPolicy: IfNotPresent
        image: 1995chen/dnf:centos5-a8dec7b
        ports:
        - name: relay-tcp
          containerPort: 7100
          protocol: TCP
        - name: relay-udp
          containerPort: 7100
          protocol: UDP
        - name: stun-tcp-01
          containerPort: 2111
          protocol: TCP
        - name: stun-udp-01
          containerPort: 2111
          protocol: UDP
        - name: stun-tcp-02
          containerPort: 2112
          protocol: TCP
        - name: stun-udp-02
          containerPort: 2112
          protocol: UDP
        - name: stun-tcp-03
          containerPort: 2113
          protocol: TCP
        - name: stun-udp-03
          containerPort: 2113
          protocol: UDP
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "800m"
            memory: "512Mi"
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: SERVER_TYPE
          value: P2P
        - name: SERVER_GROUP
          value: "1"
        # 这里可以使用dnf-cain-p2p的ServiceIP
        - name: PUBLIC_IP
          value: dnf-cain-p2p.dnf-server.svc.cluster.local
        # 这里可以使用dnf-cain-core的ServiceIP
        - name: CORE_PUBLIC_IP
          value: dnf-cain-core.dnf-server.svc.cluster.local
        - name: P2P_RELAY_INDEX
          value: "201"
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data_cain_p2p
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf-diregie-p2p
  namespace: dnf-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf-diregie-p2p
  template:
    metadata:
      labels:
        app: dnf-diregie-p2p
    spec:
      restartPolicy: Always
      volumes:
      - name: dnf
        persistentVolumeClaim:
          claimName: dnf
      containers:
      - name: dnf
        imagePullPolicy: IfNotPresent
        image: 1995chen/dnf:centos5-a8dec7b
        ports:
        - name: relay-tcp
          containerPort: 7200
          protocol: TCP
        - name: relay-udp
          containerPort: 7200
          protocol: UDP
        - name: stun-tcp-01
          containerPort: 2211
          protocol: TCP
        - name: stun-udp-01
          containerPort: 2211
          protocol: UDP
        - name: stun-tcp-02
          containerPort: 2212
          protocol: TCP
        - name: stun-udp-02
          containerPort: 2212
          protocol: UDP
        - name: stun-tcp-03
          containerPort: 2213
          protocol: TCP
        - name: stun-udp-03
          containerPort: 2213
          protocol: UDP
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "800m"
            memory: "512Mi"
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: SERVER_TYPE
          value: P2P
        - name: SERVER_GROUP
          value: "2"
        # 这里可以使用dnf-diregie-p2p的ServiceIP
        - name: PUBLIC_IP
          value: dnf-diregie-p2p.dnf-server.svc.cluster.local
        # 这里可以使用dnf-diregie-core的ServiceIP
        - name: CORE_PUBLIC_IP
          value: dnf-diregie-core.dnf-server.svc.cluster.local
        - name: P2P_RELAY_INDEX
          value: "201"
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data_diregie_p2p
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf-siroco-p2p
  namespace: dnf-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf-siroco-p2p
  template:
    metadata:
      labels:
        app: dnf-siroco-p2p
    spec:
      restartPolicy: Always
      volumes:
      - name: dnf
        persistentVolumeClaim:
          claimName: dnf
      containers:
      - name: dnf
        imagePullPolicy: IfNotPresent
        image: 1995chen/dnf:centos5-a8dec7b
        ports:
        - name: relay-tcp
          containerPort: 7300
          protocol: TCP
        - name: relay-udp
          containerPort: 7300
          protocol: UDP
        - name: stun-tcp-01
          containerPort: 2311
          protocol: TCP
        - name: stun-udp-01
          containerPort: 2311
          protocol: UDP
        - name: stun-tcp-02
          containerPort: 2312
          protocol: TCP
        - name: stun-udp-02
          containerPort: 2312
          protocol: UDP
        - name: stun-tcp-03
          containerPort: 2313
          protocol: TCP
        - name: stun-udp-03
          containerPort: 2313
          protocol: UDP
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "800m"
            memory: "512Mi"
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: SERVER_TYPE
          value: P2P
        - name: SERVER_GROUP
          value: "3"
        # 这里可以使用dnf-siroco-p2p的ServiceIP
        - name: PUBLIC_IP
          value: dnf-siroco-p2p.dnf-server.svc.cluster.local
        # 这里可以使用dnf-siroco-core的ServiceIP
        - name: CORE_PUBLIC_IP
          value: dnf-siroco-core.dnf-server.svc.cluster.local
        - name: P2P_RELAY_INDEX
          value: "201"
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data_siroco_p2p
EOF
```

## 创建DNF GAME服务

```bash
# 创建GAME Service
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: dnf-cain-game
  namespace: dnf-server
  labels:
    app: dnf-cain-game
spec:
  ports:
    - name: ch11-tcp
      port: 10011
      protocol: TCP
    - name: ch11-udp
      port: 11011
      protocol: UDP
  selector:
    app: dnf-cain-game
---
apiVersion: v1
kind: Service
metadata:
  name: dnf-diregie-game
  namespace: dnf-server
  labels:
    app: dnf-diregie-game
spec:
  ports:
    - name: ch12-tcp
      port: 20012
      protocol: TCP
    - name: ch12-udp
      port: 21012
      protocol: UDP
  selector:
    app: dnf-diregie-game
---
apiVersion: v1
kind: Service
metadata:
  name: dnf-siroco-game
  namespace: dnf-server
  labels:
    app: dnf-siroco-game
spec:
  ports:
    - name: ch13-tcp
      port: 30013
      protocol: TCP
    - name: ch13-udp
      port: 31013
      protocol: UDP
    - name: ch52-tcp
      port: 30052
      protocol: TCP
    - name: ch52-udp
      port: 31052
      protocol: UDP
  selector:
    app: dnf-siroco-game
EOF

# 创建Game服务
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf-cain-game
  namespace: dnf-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf-cain-game
  template:
    metadata:
      labels:
        app: dnf-cain-game
    spec:
      restartPolicy: Always
      volumes:
      - name: dnf
        persistentVolumeClaim:
          claimName: dnf
      # 【不可删除】，docker等容器运行时默认较小，需要增加才能保证运行
      - name: memory
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi
      containers:
      - name: dnf
        imagePullPolicy: IfNotPresent
        image: 1995chen/dnf:centos5-a8dec7b
        ports:
        - name: ch11-tcp
          containerPort: 10011
          protocol: TCP
        - name: ch11-udp
          containerPort: 11011
          protocol: UDP
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "1000m"
            memory: "4Gi"
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: SERVER_TYPE
          value: GAME
        - name: SERVER_GROUP
          value: "1"
        - name: SERVER_GROUP_DB
          value: cain
        - name: OPEN_CHANNEL
          value: "11"
        # 这里填写真实要访问GAME服务的公网IP[后续需要在这台机器部署转发服务]
        - name: PUBLIC_IP
          value: xx.xx.xx.xx
        # 这里填写真实要访问P2P服务的公网IP[后续需要在这台机器部署转发服务]
        - name: P2P_PUBLIC_IP
          value: xx.xx.xx.xx
        # 这里可以使用dnf-cain-core的ServiceIP
        - name: MAIN_BRIDGE_IP
          value: dnf-cain-core.dnf-server.svc.cluster.local
        # 这里可以使用dnf-cain-core的ServiceIP
        - name: CORE_PUBLIC_IP
          value: dnf-cain-core.dnf-server.svc.cluster.local
        - name: MAIN_MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MAIN_MYSQL_PORT
          value: "3306"
        - name: MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MYSQL_PORT
          value: "3306"
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data_cain_game
        - mountPath: /dev/shm
          name: memory
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf-diregie-game
  namespace: dnf-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf-diregie-game
  template:
    metadata:
      labels:
        app: dnf-diregie-game
    spec:
      restartPolicy: Always
      volumes:
      - name: dnf
        persistentVolumeClaim:
          claimName: dnf
      # 【不可删除】，docker等容器运行时默认较小，需要增加才能保证运行
      - name: memory
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi
      containers:
      - name: dnf
        imagePullPolicy: IfNotPresent
        image: 1995chen/dnf:centos5-a8dec7b
        ports:
        - name: ch12-tcp
          containerPort: 20012
          protocol: TCP
        - name: ch12-udp
          containerPort: 21012
          protocol: UDP
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "1000m"
            memory: "4Gi"
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: SERVER_TYPE
          value: GAME
        - name: SERVER_GROUP
          value: "2"
        - name: SERVER_GROUP_DB
          value: diregie
        - name: OPEN_CHANNEL
          value: "12"
        # 这里填写真实要访问GAME服务的公网IP[后续需要在这台机器部署转发服务]
        - name: PUBLIC_IP
          value: 42.192.110.79
        # 这里填写真实要访问P2P服务的公网IP[后续需要在这台机器部署转发服务]
        - name: P2P_PUBLIC_IP
          value: 42.192.110.79
        # 这里可以使用dnf-cain-core的ServiceIP
        - name: MAIN_BRIDGE_IP
          value: dnf-cain-core.dnf-server.svc.cluster.local
        # 这里可以使用dnf-cain-core的ServiceIP
        - name: CORE_PUBLIC_IP
          value: dnf-diregie-core.dnf-server.svc.cluster.local
        - name: MAIN_MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MAIN_MYSQL_PORT
          value: "3306"
        - name: MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MYSQL_PORT
          value: "3306"
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data_diregie_game
        - mountPath: /dev/shm
          name: memory
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf-siroco-game
  namespace: dnf-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf-siroco-game
  template:
    metadata:
      labels:
        app: dnf-siroco-game
    spec:
      restartPolicy: Always
      volumes:
      - name: dnf
        persistentVolumeClaim:
          claimName: dnf
      # 【不可删除】，docker等容器运行时默认较小，需要增加才能保证运行
      - name: memory
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi
      containers:
      - name: dnf
        imagePullPolicy: IfNotPresent
        image: 1995chen/dnf:centos5-a8dec7b
        ports:
        - name: ch13-tcp
          containerPort: 30013
          protocol: TCP
        - name: ch13-udp
          containerPort: 31013
          protocol: UDP
        - name: ch52-tcp
          containerPort: 30052
          protocol: TCP
        - name: ch52-udp
          containerPort: 31052
          protocol: UDP
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "1000m"
            memory: "4Gi"
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: SERVER_TYPE
          value: GAME
        - name: SERVER_GROUP
          value: "3"
        - name: SERVER_GROUP_DB
          value: siroco
        - name: OPEN_CHANNEL
          value: "13,52"
        # 这里填写真实要访问GAME服务的公网IP[后续需要在这台机器部署转发服务]
        - name: PUBLIC_IP
          value: 42.192.110.79
        # 这里填写真实要访问P2P服务的公网IP[后续需要在这台机器部署转发服务]
        - name: P2P_PUBLIC_IP
          value: 42.192.110.79
        # 这里可以使用dnf-cain-core的ServiceIP
        - name: MAIN_BRIDGE_IP
          value: dnf-cain-core.dnf-server.svc.cluster.local
        # 这里可以使用dnf-cain-core的ServiceIP
        - name: CORE_PUBLIC_IP
          value: dnf-siroco-core.dnf-server.svc.cluster.local
        - name: MAIN_MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MAIN_MYSQL_PORT
          value: "3306"
        - name: MYSQL_HOST
          value: dnf-mysql.dnf-server.svc.cluster.local
        - name: MYSQL_PORT
          value: "3306"
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data_siroco_game
        - mountPath: /dev/shm
          name: memory
EOF
```

## 创建转发服务

为了将内网的端口暴露到公网服务器,通过将pod固定到某个公有云节点,并绑定hostport来实现
原理就是GAME服务指定的PUBLIC_IP会在游戏客户端进入频道时连接，所以只需要确保客户端可以正常连接到PUBLIC_IP对应的端口就可以

```bash
# 创建FRPS
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: dnf-frps-config
  namespace: dnf-server
data:
  frps.toml: |
    bindPort = 3000
    auth.method = "token"
    auth.token = "<FRPS PASSWORD>"

    [transport]
    maxPoolCount = 40960
    tcpMux = true
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: dnf-frps
  namespace: dnf-server
spec:
  selector:
    matchLabels:
      app: dnf-frps
  template:
    metadata:
      labels:
        app: dnf-frps
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      restartPolicy: Always
      nodeSelector:
        # 这里调度到指定节点,替换PUBLIC_IP对应的公有云
        kubernetes.io/hostname: tx-node-1
      containers:
      - name: frps
        image: docker.io/snowdreamtech/frps:latest
        imagePullPolicy: IfNotPresent
        args: ["frps", "-c", "/etc/frp/frps.toml"]
        volumeMounts:
        - name: config
          mountPath: /etc/frp
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
      volumes:
      - name: config
        configMap:
          name: dnf-frps-config
---
apiVersion: v1
kind: Service
metadata:
  name: dnf-frps
  namespace: dnf-server
spec:
  selector:
    app: dnf-frps
  ports:
  - name: frps-control
    port: 3000
    targetPort: 3000
    protocol: TCP
EOF

# 创建FRPC
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: dnf-frpc-config
  namespace: dnf-server
data:
  frpc.toml: |
    serverAddr = "dnf-frps.dnf-server.svc.cluster.local"
    serverPort = 3000
    auth.method = "token"
    auth.token = "<FRPS PASSWORD>"

    [transport]
    poolCount = 4096
    tcpMux = true
    tcpMuxKeepaliveInterval = 30

    [[proxies]]
    name = "cain-core-7600-tcp"
    type = "tcp"
    localIP = "dnf-cain-core.dnf-server.svc.cluster.local"
    localPort = 7600
    remotePort = 7600

    [[proxies]]
    name = "cain-core-881-tcp"
    type = "tcp"
    localIP = "dnf-cain-core.dnf-server.svc.cluster.local"
    localPort = 881
    remotePort = 881

    [[proxies]]
    name = "cain-core-7001-tcp"
    type = "tcp"
    localIP = "dnf-cain-core.dnf-server.svc.cluster.local"
    localPort = 7001
    remotePort = 7001

    [[proxies]]
    name = "cain-core-7001-udp"
    type = "udp"
    localIP = "dnf-cain-core.dnf-server.svc.cluster.local"
    localPort = 7001
    remotePort = 7001

    [[proxies]]
    name = "cain-p2p-7100-tcp"
    type = "tcp"
    localIP = "dnf-cain-p2p.dnf-server.svc.cluster.local"
    localPort = 7100
    remotePort = 7100

    [[proxies]]
    name = "cain-p2p-7100-udp"
    type = "udp"
    localIP = "dnf-cain-p2p.dnf-server.svc.cluster.local"
    localPort = 7100
    remotePort = 7100

    [[proxies]]
    name = "cain-p2p-2111-tcp"
    type = "tcp"
    localIP = "dnf-cain-p2p.dnf-server.svc.cluster.local"
    localPort = 2111
    remotePort = 2111

    [[proxies]]
    name = "cain-p2p-2111-udp"
    type = "udp"
    localIP = "dnf-cain-p2p.dnf-server.svc.cluster.local"
    localPort = 2111
    remotePort = 2111

    [[proxies]]
    name = "cain-p2p-2112-tcp"
    type = "tcp"
    localIP = "dnf-cain-p2p.dnf-server.svc.cluster.local"
    localPort = 2112
    remotePort = 2112

    [[proxies]]
    name = "cain-p2p-2112-udp"
    type = "udp"
    localIP = "dnf-cain-p2p.dnf-server.svc.cluster.local"
    localPort = 2112
    remotePort = 2112

    [[proxies]]
    name = "cain-p2p-2113-tcp"
    type = "tcp"
    localIP = "dnf-cain-p2p.dnf-server.svc.cluster.local"
    localPort = 2113
    remotePort = 2113

    [[proxies]]
    name = "cain-p2p-2113-udp"
    type = "udp"
    localIP = "dnf-cain-p2p.dnf-server.svc.cluster.local"
    localPort = 2113
    remotePort = 2113

    [[proxies]]
    name = "diregie-p2p-7200-tcp"
    type = "tcp"
    localIP = "dnf-diregie-p2p.dnf-server.svc.cluster.local"
    localPort = 7200
    remotePort = 7200

    [[proxies]]
    name = "diregie-p2p-7200-udp"
    type = "udp"
    localIP = "dnf-diregie-p2p.dnf-server.svc.cluster.local"
    localPort = 7200
    remotePort = 7200

    [[proxies]]
    name = "diregie-p2p-2211-tcp"
    type = "tcp"
    localIP = "dnf-diregie-p2p.dnf-server.svc.cluster.local"
    localPort = 2211
    remotePort = 2211

    [[proxies]]
    name = "diregie-p2p-2211-udp"
    type = "udp"
    localIP = "dnf-diregie-p2p.dnf-server.svc.cluster.local"
    localPort = 2211
    remotePort = 2211

    [[proxies]]
    name = "diregie-p2p-2212-tcp"
    type = "tcp"
    localIP = "dnf-diregie-p2p.dnf-server.svc.cluster.local"
    localPort = 2212
    remotePort = 2212

    [[proxies]]
    name = "diregie-p2p-2212-udp"
    type = "udp"
    localIP = "dnf-diregie-p2p.dnf-server.svc.cluster.local"
    localPort = 2212
    remotePort = 2212

    [[proxies]]
    name = "diregie-p2p-2213-tcp"
    type = "tcp"
    localIP = "dnf-diregie-p2p.dnf-server.svc.cluster.local"
    localPort = 2213
    remotePort = 2213

    [[proxies]]
    name = "diregie-p2p-2213-udp"
    type = "udp"
    localIP = "dnf-diregie-p2p.dnf-server.svc.cluster.local"
    localPort = 2213
    remotePort = 2213

    [[proxies]]
    name = "siroco-p2p-7300-tcp"
    type = "tcp"
    localIP = "dnf-siroco-p2p.dnf-server.svc.cluster.local"
    localPort = 7300
    remotePort = 7300

    [[proxies]]
    name = "siroco-p2p-7300-udp"
    type = "udp"
    localIP = "dnf-siroco-p2p.dnf-server.svc.cluster.local"
    localPort = 7300
    remotePort = 7300

    [[proxies]]
    name = "siroco-p2p-2311-tcp"
    type = "tcp"
    localIP = "dnf-siroco-p2p.dnf-server.svc.cluster.local"
    localPort = 2311
    remotePort = 2311

    [[proxies]]
    name = "siroco-p2p-2311-udp"
    type = "udp"
    localIP = "dnf-siroco-p2p.dnf-server.svc.cluster.local"
    localPort = 2311
    remotePort = 2311

    [[proxies]]
    name = "siroco-p2p-2312-tcp"
    type = "tcp"
    localIP = "dnf-siroco-p2p.dnf-server.svc.cluster.local"
    localPort = 2312
    remotePort = 2312

    [[proxies]]
    name = "siroco-p2p-2312-udp"
    type = "udp"
    localIP = "dnf-siroco-p2p.dnf-server.svc.cluster.local"
    localPort = 2312
    remotePort = 2312

    [[proxies]]
    name = "siroco-p2p-2313-tcp"
    type = "tcp"
    localIP = "dnf-siroco-p2p.dnf-server.svc.cluster.local"
    localPort = 2313
    remotePort = 2313

    [[proxies]]
    name = "siroco-p2p-2313-udp"
    type = "udp"
    localIP = "dnf-siroco-p2p.dnf-server.svc.cluster.local"
    localPort = 2313
    remotePort = 2313

    [[proxies]]
    name = "cain-game-10011-tcp"
    type = "tcp"
    localIP = "dnf-cain-game.dnf-server.svc.cluster.local"
    localPort = 10011
    remotePort = 10011

    [[proxies]]
    name = "cain-game-11011-udp"
    type = "udp"
    localIP = "dnf-cain-game.dnf-server.svc.cluster.local"
    localPort = 11011
    remotePort = 11011

    [[proxies]]
    name = "diregie-game-20012-tcp"
    type = "tcp"
    localIP = "dnf-diregie-game.dnf-server.svc.cluster.local"
    localPort = 20012
    remotePort = 20012

    [[proxies]]
    name = "diregie-game-21012-udp"
    type = "udp"
    localIP = "dnf-diregie-game.dnf-server.svc.cluster.local"
    localPort = 21012
    remotePort = 21012

    [[proxies]]
    name = "siroco-game-30013-tcp"
    type = "tcp"
    localIP = "dnf-siroco-game.dnf-server.svc.cluster.local"
    localPort = 30013
    remotePort = 30013

    [[proxies]]
    name = "siroco-game-31013-udp"
    type = "udp"
    localIP = "dnf-siroco-game.dnf-server.svc.cluster.local"
    localPort = 31013
    remotePort = 31013

    [[proxies]]
    name = "siroco-game-30052-tcp"
    type = "tcp"
    localIP = "dnf-siroco-game.dnf-server.svc.cluster.local"
    localPort = 30052
    remotePort = 30052

    [[proxies]]
    name = "siroco-game-31052-udp"
    type = "udp"
    localIP = "dnf-siroco-game.dnf-server.svc.cluster.local"
    localPort = 31052
    remotePort = 31052
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf-frpc
  namespace: dnf-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf-frpc
  template:
    metadata:
      labels:
        app: dnf-frpc
    spec:
      restartPolicy: Always
      containers:
      - name: frpc
        image: docker.io/snowdreamtech/frpc:latest
        imagePullPolicy: IfNotPresent
        args: ["frpc", "-c", "/etc/frp/frpc.toml"]
        volumeMounts:
        - name: config
          mountPath: /etc/frp
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "300m"
            memory: "256Mi"
      volumes:
      - name: config
        configMap:
          name: dnf-frpc-config
EOF
```
