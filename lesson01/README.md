# Lesson 01

## Building

Ensure that Docker is running and then run the following script:

```bash
./build.sh
```

## Running

Run using the `-kernel` flag and pass in the elf file. This makes qemu automatically start running the code on all four cores. Passing in the kernel8.img file will result in qemu running this code on one core while keeping the other cores occupied and the code would need to handle activating each core and passing an address.

```bash
qemu-system-aarch64 -M raspi3b -kernel ./build/kernel8.elf -smp 4 -serial null -serial stdio
```

## Debugging

In one terminal, run qemu:

```bash
qemu-system-aarch64 -M raspi3b -kernel ./build/kernel8.elf -s -S -smp 4 -serial null -serial stdio 
```

In another, run gdb and connect it to qemu:

```bash
aarch64-linux-gnu-gdb ./build/kernel8.elf -ex 'target remote localhost:1234' -ex 'break *0x00000'
```

Execution will be paused initially with all cores showing:

```
(gdb) info threads
  Id   Target Id                    Frame
* 1    Thread 1.1 (CPU#0 [running]) uart_send (c=<error reading variable: Cannot access memory at address 0xffffffffffffffff>) at src/mini_uart.c:6
  2    Thread 1.2 (CPU#1 [running]) uart_send (c=<error reading variable: Cannot access memory at address 0xffffffffffffffff>) at src/mini_uart.c:6
  3    Thread 1.3 (CPU#2 [running]) uart_send (c=<error reading variable: Cannot access memory at address 0xffffffffffffffff>) at src/mini_uart.c:6
  4    Thread 1.4 (CPU#3 [running]) uart_send (c=<error reading variable: Cannot access memory at address 0xffffffffffffffff>) at src/mini_uart.c:6
```

You can hit `c` to allow execution to continue, or use `s` to step through while the code runs.

## Issues

As described in boot.S, the number of opcodes in the file seems to affect whether the code works or infinitely loops when running in multi-core mode. The code will always work when only Core#0 is running the code (when passing kernel8.img to qemu). Adding `nop` or removing `nop` has this affect, as does adding/removing any other opcodes.