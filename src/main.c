#include <stdio.h>
#include <signal.h>
#include "../include/server.h"

static Server* global_server = NULL;

void signal_handler(int signum) {
    printf("\nShutting down server (signal %d)...\n", signum);
    if (global_server != NULL) {
        server_stop(global_server);
    }
}

int main(void) {
    // Setup signal handler for graceful shutdown
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    Server* srv = server_create(PORT);
    if (srv == NULL) {
        fprintf(stderr, "Failed to create server\n");
        return 1;
    }

    global_server = srv;

    if (server_bind(srv) < 0) {
        fprintf(stderr, "Failed to bind server\n");
        server_destroy(srv);
        return 1;
    }

    printf("Starting server...\n");
    server_start(srv);

    // Cleanup
    printf("Cleaning up...\n");
    server_destroy(srv);
    global_server = NULL;

    return 0;
}
