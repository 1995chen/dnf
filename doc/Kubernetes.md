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
stringData:
  mysql_root_password: "88888888"
  gate_aes_key: a1b2c3d4e5f6789012345678901234567890abcdef0123456789abcdef012345

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
      # 【不可删除】，docker等容器运行时默认较小，需要增加才能保证运行
      - name: memory
        emptyDir:
          medium: Memory
          sizeLimit: 1Gi

      containers:
      - name: dnf
        imagePullPolicy: IfNotPresent
        image: llnut/dnf:debian13-qf1031-latest
        ports:
        - name: mysql
          containerPort: 3306
          protocol: TCP
          hostPort: 3000
        - name: gate-tcp
          containerPort: 5505
          protocol: TCP
          hostPort: 5505
        - name: channel-tcp1
          containerPort: 7001
          protocol: TCP
          hostPort: 7001
        - name: channel-udp1
          containerPort: 7001
          protocol: UDP
          hostPort: 7001
        - name: game-tcp1
          containerPort: 30011
          protocol: TCP
          hostPort: 30011
        - name: game-tcp2
          containerPort: 30052
          protocol: TCP
          hostPort: 30052
        - name: game-udp1
          containerPort: 31011
          protocol: UDP
          hostPort: 31011
        - name: game-udp2
          containerPort: 31052
          protocol: UDP
          hostPort: 31052
        - name: relay-tcp1
          containerPort: 7300
          protocol: TCP
          hostPort: 7300
        - name: relay-udp1
          containerPort: 7300
          protocol: UDP
          hostPort: 7300
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
        - name: GATE_AES_KEY
          valueFrom:
            secretKeyRef:
              key: gate_aes_key
              name: dnf
        volumeMounts:
        - mountPath: /data
          name: dnf
          subPath: data
        - mountPath: /var/lib/mysql
          name: dnf
          subPath: mysql
        - mountPath: /home/neople/game/log
          name: dnf
          subPath: log
        - mountPath: /dev/shm
          name: memory
```

## 一些说明
yaml中"nodeName: centos-02"是为了固定在一个节点上运行，实际运行时，这块按照实际需要修改。

ConfigMap中的dnf_public_ip为实际运行节点的内网/公网IP

如果使用Netbird则不需要固定在某个固定节点
