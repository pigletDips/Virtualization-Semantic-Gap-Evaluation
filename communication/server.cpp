#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iostream>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <sys/shm.h>

#define PORT 7000
#define QUEUE 2/* 侦听队列长度 */

using namespace std;

extern void process_conn_server(int *s); 

int main()
{
	int ss, sc[2];
	struct sockaddr_in server_addr;
	struct sockaddr_in client_addr;
	int err;
	pid_t pid;

	ss = socket(AF_INET, SOCK_STREAM, 0);
	if(ss < 0){
		cout << "socket creation failed" << endl;
		return -1;
	}

	/* 设置服务器地址 */
	memset(&server_addr, 0, sizeof(server_addr));
	server_addr.sin_family = AF_INET;
	server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	server_addr.sin_port = htons(PORT);

	/* 绑定地址结构到套接字 */
	err = bind(ss, (struct sockaddr*)&server_addr, sizeof(server_addr));
	if(err < 0){
		cout << "bind failed" << endl;
		return -1;
	}
	/* 设置监听 */
	err = listen(ss, QUEUE);
	if(err < 0){
		cout << "listen error" << endl;
		return -1;
	}

	/* 主循环 */
	socklen_t addrlen = sizeof(struct sockaddr);
	for(;;){
		sc[0] = accept(ss, (struct sockaddr*)&client_addr, &addrlen);
		if(sc[0] < 0){
			continue;
		}
	
		sc[1] = accept(ss, (struct sockaddr*)&client_addr, &addrlen);
		if(sc[1] < 0){
			continue;
		}
		if(sc[0] > 0 && sc[1] > 0){
			process_conn_server(sc);/* 处理连接 */
		}
	
	}

	return 0;
}




