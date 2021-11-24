# Kubernetes 部署DNF

## Yaml

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dnf
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10G

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dnf
data:
  dnf_public_ip: 192.168.0.203

---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: dnf
data:
  mysql_root_password: ODg4ODg4ODg=
  gm_account: Y2hlbmxpYW5n
  gm_password: RGFuZGFuMjY5MTMy

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dnf
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dnf
  template:
    metadata:
      labels:
        app: dnf
    spec:
      restartPolicy: Always
      nodeName: centos-02
      volumes:
      - name: dnf
        persistentVolumeClaim:
          claimName: dnf
      - name: memory
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi

      initContainers:
      - name: init-data
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: PUBLIC_IP
          valueFrom:
            configMapKeyRef:
              key: dnf_public_ip
              name: dnf
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
        image: 1995chen/dnf:2882e1a
        imagePullPolicy: IfNotPresent
        command: ["/bin/bash"]
        args: ["/home/template/init/init.sh"]
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data
        - mountPath: /var/lib/mysql
          name: dnf
          subPath: mysql
      containers:
      - name: dnf
        imagePullPolicy: IfNotPresent
        image: 1995chen/dnf:2882e1a
        ports:
        - name: mysql
          containerPort: 3306
          protocol: TCP
          hostPort: 3000 
        - name: gate-tcp1
          containerPort: 7600
          protocol: TCP
          hostPort: 7600
        - name: gate-tcp2
          containerPort: 881
          protocol: TCP
          hostPort: 881
        - name: dbmw-tcp1
          containerPort: 20303
          protocol: TCP
          hostPort: 20303
        - name: dbmw-tcp2
          containerPort: 20403
          protocol: TCP
          hostPort: 20403
        - name: dbmw-tcp3
          containerPort: 20203
          protocol: TCP
          hostPort: 20203
        - name: dbmw-udp1
          containerPort: 20403
          protocol: UDP
          hostPort: 20403
        - name: dbmw-udp2
          containerPort: 20303
          protocol: UDP
          hostPort: 20303
        - name: dbmw-udp3
          containerPort: 20203
          protocol: UDP
          hostPort: 20203
        - name: manager-tcp1
          containerPort: 40403
          protocol: TCP
          hostPort: 40403
        - name: manager-udp1
          containerPort: 40403
          protocol: UDP
          hostPort: 40403
        - name: bridge-tcp1
          containerPort: 7000
          protocol: TCP
          hostPort: 7000
        - name: bridge-udp1
          containerPort: 7000
          protocol: UDP
          hostPort: 7000
        - name: channel-tcp1
          containerPort: 7001
          protocol: TCP
          hostPort: 7001
        - name: channel-udp1
          containerPort: 7001
          protocol: UDP
          hostPort: 7001
        - name: game-tcp1
          containerPort: 10011
          protocol: TCP
          hostPort: 10011
        - name: game-tcp2
          containerPort: 10052
          protocol: TCP
          hostPort: 10052
        - name: game-tcp3
          containerPort: 20011
          protocol: TCP
          hostPort: 20011
        - name: game-udp1
          containerPort: 11011
          protocol: UDP
          hostPort: 11011
        - name: game-udp2
          containerPort: 11052
          protocol: UDP
          hostPort: 11052
        - name: community-tcp1
          containerPort: 31100
          protocol: TCP
          hostPort: 31100
        - name: monitor-tcp1
          containerPort: 30303
          protocol: TCP
          hostPort: 30303
        - name: monitor-udp1
          containerPort: 30303
          protocol: UDP
          hostPort: 30303
        - name: relay-tcp1
          containerPort: 7200
          protocol: TCP
          hostPort: 7200
        - name: relay-udp1
          containerPort: 7200
          protocol: UDP
          hostPort: 7200
        - name: guild-tcp1
          containerPort: 30403
          protocol: TCP
          hostPort: 30403
        - name: guild-udp1
          containerPort: 30403
          protocol: UDP
          hostPort: 30403
        - name: coserver-udp1
          containerPort: 30703
          protocol: UDP
          hostPort: 30703
        - name: stun-udp1
          containerPort: 2311
          protocol: UDP
          hostPort: 2311
        - name: stun-udp2
          containerPort: 2312
          protocol: UDP
          hostPort: 2312
        - name: stun-udp3
          containerPort: 2313
          protocol: UDP
          hostPort: 2313
        - name: statics-udp1
          containerPort: 30503
          protocol: UDP
          hostPort: 30503
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: PUBLIC_IP
          valueFrom:
            configMapKeyRef:
              key: dnf_public_ip
              name: dnf
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
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data
        - mountPath: /var/lib/mysql
          name: dnf
          subPath: mysql
        - mountPath: /dev/shm
          name: memory
```
