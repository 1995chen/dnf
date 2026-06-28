#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>

typedef int (*orig_bind_t)(int, const struct sockaddr*, socklen_t);
orig_bind_t orig_bind = NULL;

static int new_ports[3] = {2311, 2312, 2313};

static void load_ports_from_cfg() {
    static int loaded = 0;
    if (loaded) return;
    loaded = 1;

    FILE *f = fopen("./cfg/server.cfg", "r");
    if (!f) f = fopen("cfg/server.cfg", "r");
    if (f) {
        int i;
        for (i = 0; i < 3; i++) {
            if (fscanf(f, "%d", &new_ports[i]) != 1) break;
        }
        fclose(f);
        printf("[STUN_HOOK] Loaded ports: %d %d %d\n", new_ports[0], new_ports[1], new_ports[2]);
    }
}

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    if (!orig_bind) {
        orig_bind = (orig_bind_t)dlsym(RTLD_NEXT, "bind");
    }

    load_ports_from_cfg();

    if (addr && addr->sa_family == AF_INET) {
        struct sockaddr_in *in = (struct sockaddr_in *)addr;
        int old_port = ntohs(in->sin_port);

        if (old_port == 2311) in->sin_port = htons(new_ports[0]);
        else if (old_port == 2312) in->sin_port = htons(new_ports[1]);
        else if (old_port == 2313) in->sin_port = htons(new_ports[2]);

        if (old_port >= 2311 && old_port <= 2313) {
            printf("[STUN_HOOK] %d -> %d\n", old_port, ntohs(in->sin_port));
        }
    }
    return orig_bind(sockfd, addr, addrlen);
}
