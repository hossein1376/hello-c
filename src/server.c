#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>
#include "../include/server.h"

Server* server_create(int port) {
    Server* srv = malloc(sizeof(Server));
    if (srv == NULL) {
        perror("allocate new server");
        return NULL;
    }
    srv->port = port;
    srv->running = 0;
    srv->socket_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (srv->socket_fd < 0) {
        perror("create socket failed");
        free(srv);
        return NULL;
    }

    // Set socket options to reuse address
        int opt = 1;
        if (setsockopt(srv->socket_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
            perror("setsockopt failed");
            close(srv->socket_fd);
            free(srv);
            return NULL;
        }

    return srv;
}

int server_bind(Server* srv) {
    if (srv == NULL) {
        return -1;
    }

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(srv->port);

    if (bind(srv->socket_fd, (struct sockaddr*)&address,
             sizeof(address)) < 0) {
        perror("bind failed");
        return -1;
    }

    if (listen(srv->socket_fd, MAX_CONN) < 0) {
        perror("listen failed");
        return -1;
    }

    printf("Server listening on port %d\n", srv->port);
    return 0;
}

void handle_request(int client_fd, const char* request) {
    // Simple routing based on first line
    if (strncmp(request, "GET / ", 6) == 0) {
        send_response(client_fd, "<h1>Hello, World!</h1>", 200);
    } else if (strncmp(request, "GET /about", 10) == 0) {
        send_response(client_fd, "<h1>About Page</h1>", 200);
    } else {
        send_response(client_fd, "<h1>404 Not Found</h1>", 404);
    }
}

void server_start(Server* srv) {
    if (srv == NULL) {
        return;
    }

    srv->running = 1;

    while (srv->running) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);

        int client_fd = accept(srv->socket_fd,
                               (struct sockaddr*)&client_addr,
                               &client_len);

        if (client_fd < 0) {
            if (errno == EINTR) {
                // Interrupted by signal, continue
                continue;
            }
            perror("accept failed");
            continue;
        }

        // Read request
        char buffer[BUFFER_SIZE];
        memset(buffer, 0, BUFFER_SIZE);

        ssize_t bytes_read = read(client_fd, buffer, BUFFER_SIZE - 1);
        if (bytes_read < 0) {
            perror("read failed");
            close(client_fd);
            continue;
        }

        printf("Received request:\n%s\n", buffer);

        // Handle request
        handle_request(client_fd, buffer);

        close(client_fd);
    }
}

void send_response(int client_fd, const char* body, int status_code) {
    char response[BUFFER_SIZE];
    const char* status_text = (status_code == 200) ? "OK" : "Not Found";

    int content_length = strlen(body);

    // Build HTTP response
    int header_len = snprintf(response, BUFFER_SIZE,
        "HTTP/1.1 %d %s\r\n"
        "Content-Type: text/html\r\n"
        "Content-Length: %d\r\n"
        "Connection: close\r\n"
        "\r\n"
        "%s",
        status_code, status_text, content_length, body);

    if (header_len < 0 || header_len >= BUFFER_SIZE) {
        fprintf(stderr, "Response too large\n");
        return;
    }

    ssize_t bytes_sent = write(client_fd, response, header_len);
    if (bytes_sent < 0) {
        perror("write failed");
    }
}

void server_stop(Server* srv) {
    if (srv != NULL) {
        srv->running = 0;
    }
}

void server_destroy(Server* srv) {
    if (srv != NULL) {
        close(srv->socket_fd);
        free(srv);
    }
}
