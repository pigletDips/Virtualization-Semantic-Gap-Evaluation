#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <iostream>
#include <sys/wait.h>
using namespace std;

static int do_command(const char *cmd)
{
	FILE *f;
	int status;

	f = popen(cmd, "r");
	if(!f)
		return 0;

	status = fclose(f);
	return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}


/* client对server的处理 */
void process_conn_client(int s, char *flag)
{
	ssize_t size = 0;
	char buffer[1024];	/* 数据的缓冲区 */

	for(;;){		/* 循环处理过程 */
		memset(buffer, 0, sizeof(buffer));
		/* 从套接字中读取数据放到缓冲区buffer中 */
		size = read(s, buffer, 1024);	
		if(size == 0){
			/* 没有数据 */
			return;	
		}
		if(strcmp(flag, "vm1") == 0){
			/* vm1 */
			if(strncmp(buffer, "start\n", size) == 0){
				sprintf(buffer, "vm1 received\n");
				write(s, buffer, strlen(buffer)+1);
				do_command("./spinlock.sh");
				memset(buffer, 0, sizeof(buffer));
				sprintf(buffer, "vm1 finished\n");
				write(s, buffer, strlen(buffer)+1);
			}else{
				write(s, buffer, strlen(buffer)+1);
			}
		}else if(strcmp(flag, "vm2") == 0){
			/* vm2 */
			if(strncmp(buffer, "start\n", size) == 0){
				sprintf(buffer, "vm2 received\n");
				write(s, buffer, strlen(buffer)+1);
				do_command("./harness.sh 8");
				memset(buffer, 0, sizeof(buffer));
				sprintf(buffer, "vm2 finished\n");
				write(s, buffer, strlen(buffer)+1);
			}else{
				write(s, buffer, strlen(buffer)+1);
			}
		}
		/* 构建响应字符，为接收到服务端字节的数量 */
//		sprintf(buffer, "%ld bytes altogether\n", size);
//		write(s, buffer, strlen(buffer)+1);/* 发给服务端 */
	}	
}

/* server的处理过程 */
void process_conn_server(int *s)
{
	ssize_t size = 0;
	char buffer[1024];	/* 数据的缓冲区 */

	for(;;){/* 循环处理过程 */
		/* 从标准输入中读取数据放到缓冲区buffer中 */
		size = read(0, buffer, 1024);
		if(size > 0){
			/* 读到数据 */
			write(s[0], buffer, size);		/* 发送给客户端 */
			write(s[1], buffer, size);		/* 发送给客户端 */
			/* 读取第一个vm */
			size = read(s[0], buffer, 1024); 	/* 从客户端读取数据 */
			write(1, buffer, size);		/* 写到标准输出 */
			size = read(s[1], buffer, 1024); 	/* 从客户端读取数据 */
			write(1, buffer, size);		/* 写到标准输出 */
			if(strcmp(buffer, "vm2 finished") == 0){
				printf("END\n");
			}
			/* 读取第一个vm */
			size = read(s[0], buffer, 1024); 	/* 从客户端读取数据 */
			write(1, buffer, size);		/* 写到标准输出 */
			size = read(s[1], buffer, 1024); 	/* 从客户端读取数据 */
			write(1, buffer, size);		/* 写到标准输出 */

			if(strcmp(buffer, "vm2 finished") == 0){
				printf("END\n");
			}

		}
	}	
}
/*
   void sig_proccess(int signo)
   {
   printf("Catch a exit signal\n");
   exit(0);	
   }

   void sig_pipe(int sign)
   {
   printf("Catch a SIGPIPE signal\n");

   }
   */

