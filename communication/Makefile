CC = g++
all:client server
	
client:tcp_process.o client.o
	$(CC) -o client tcp_process.o client.o
server:tcp_process.o server.o
	$(CC) -o server tcp_process.o server.o
clean:
	rm -f client server *.o



