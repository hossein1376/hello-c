#ifndef SERVER_H
#define SERVER_H

#include <stdint.h>

#define PORT 8080
#define BUFFER_SIZE 4096
#define MAX_CONN 10

typedef struct {
    int socket_fd;
    int port;
    int running;
} Server;

typedef struct {
    int client_fd;
    char buffer[BUFFER_SIZE];
} ClientContext;

Server* server_create(int port);
int server_bind(Server* server);
void server_start(Server* server);
void server_stop(Server* server);
void server_destroy(Server* server);

void handle_requests(int client_fd, const char* request);
void send_response(int client_fd, const char* body, int status_code);

#endif
