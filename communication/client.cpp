#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iostream>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <linux/in.h>
#include <signal.h>


#define PORT 7000
#define BUFFER_SIZE 1024

using namespace std;

/*
 * 1 - vm1
 * 2 - vm2
 * */

extern void process_conn_client(int s, char *flag);

int main(int argc, char *argv[])
{
	int sc;					/* 客户端的socket描述符 */
	struct sockaddr_in server_addr; 	/* 服务器地址结构 */
	char *vm;

	vm = argv[2];

	sc = socket(AF_INET, SOCK_STREAM, 0);  	/* 建立流式套接字 */
	if(sc < 0){
		cout << "socket error" << endl;
		return -1;
	}

	/* 设置服务器地址 */
	memset(&server_addr, 0, sizeof(server_addr));
	server_addr.sin_family = AF_INET;
	server_addr.sin_addr.s_addr = htonl(INADDR_ANY); ///服务器ip
	server_addr.sin_port = htons(PORT); ///服务器端口
	
	/* 将用户输入的字符串类型的IP地址转为整型 */
	inet_pton(AF_INET, argv[1], &server_addr.sin_addr);

	/* 连接服务器 */
	if (connect(sc, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0)
	{
		cout << "connect error" << endl;
		return -1;
	}

	process_conn_client(sc, vm);

	close(sc);
	return 0;	
}


