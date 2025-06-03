package main

import (
    "io"
    "log"
    "net"
    "sync"
    "flag"
    "strings"
)

type Proxy struct {
    Protocol       string
    Addr           string
    TargetProtocol string
    TargetAddr     string
}

func main() {
    targetAddrs := flag.String("forward", "3306/mysql:3306/tcp", "Comma-separated list of forward rules (e.g., 3306/mysql:3306/tcp,2000/mysql:8000/tcp)")
    flag.Parse()
    addrs := strings.Split(*targetAddrs, ",")

    var proxies []Proxy
    for _, addr := range addrs {
        parts := strings.Split(addr, "/")
        if len(parts) != 3 {
            log.Fatalf("Invalid forward rule: %s", addr)
        }
        proxies = append(proxies, Proxy{
            Protocol:       "tcp",
            Addr:           "0.0.0.0:" + parts[0],
            TargetProtocol: parts[2],
            TargetAddr:     parts[1],
        })
    }

    var wg sync.WaitGroup
    for _, p := range proxies {
        wg.Add(1)
        go func(p Proxy) {
            defer wg.Done()
            proxy_port(p.Protocol, p.Addr, p.TargetProtocol, p.TargetAddr)
        }(p)
    }
    wg.Wait()
}

func proxy_port(protocol string, addr string, target_protocol string, target_addr string) {
    log.Printf("Forward %s/%s--->%s/%s", addr, protocol, target_addr, target_protocol)
    listen, err := net.Listen(protocol, addr)
    if err != nil {
        log.Fatalf("Failed to set up listener: %v", err)
        return
    }
    defer listen.Close()
    for {
        conn, err := listen.Accept()
        if err != nil {
            log.Printf("Failed to accept connection: %v", err)
            continue
        }
        go func(conn net.Conn) {
			defer conn.Close()
			handleConnection(conn, target_protocol, target_addr)
		}(conn)
    }
}

func handleConnection(src net.Conn, target_protocol string, target_addr string) {
    dst, err := net.Dial(target_protocol, target_addr)
    if err != nil {
        log.Printf("Failed to connect to destination: %v", err)
        return
    }
    defer dst.Close()
    var wg sync.WaitGroup
    wg.Add(2)

    go func() {
        defer wg.Done()
        copyData(dst, src)
    }()

    go func() {
        defer wg.Done()
        copyData(src, dst)
    }()

    wg.Wait()
}

func copyData(dst net.Conn, src net.Conn) {
    _, err := io.Copy(dst, src)
    if err != nil {
        log.Printf("Failed to copy data: %v", err)
    }
    // Close `dst` to ensure that the other direction exits properly
	_ = dst.Close()
}
