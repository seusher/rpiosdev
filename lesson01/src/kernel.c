#include "mini_uart.h"
#include "utils.h"

void kernel_main(int core)
{
	uart_init();

	char* msg = "primary: ";
	uart_send_string(msg);
	uart_send((char)core+48);

	/*while (1) {
		uart_send(uart_recv());
	}*/
}

void kernel_other(int core)
{
	delay(core * 500000);

	char* msg = "\r\nsecondary: ";
	uart_send_string(msg);
	uart_send((char)core+48);


	/*while (1) {
		uart_send(uart_recv());
	}*/
}

