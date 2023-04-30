ARMGNU ?= aarch64-linux-gnu

COPS = -Wall -nostdlib -nostartfiles -ffreestanding -Iinclude -mgeneral-regs-only -g -O0
ASMOPS = -Iinclude 

BUILD_DIR = build
SRC_DIR = src

all : kernel8.img

clean :
	rm -rf $(BUILD_DIR) *.img 

$(BUILD_DIR)/%_c.o: $(SRC_DIR)/%.c
	mkdir -p $(@D)
	$(ARMGNU)-gcc $(COPS) -MMD -c $< -o $@

$(BUILD_DIR)/%_s.o: $(SRC_DIR)/%.S
	$(ARMGNU)-gcc $(ASMOPS) -MMD -c $< -o $@

C_FILES = $(wildcard $(SRC_DIR)/*.c)
ASM_FILES = $(wildcard $(SRC_DIR)/*.S)
OBJ_FILES = $(C_FILES:$(SRC_DIR)/%.c=$(BUILD_DIR)/%_c.o)
OBJ_FILES += $(ASM_FILES:$(SRC_DIR)/%.S=$(BUILD_DIR)/%_s.o)

DEP_FILES = $(OBJ_FILES:%.o=%.d)
-include $(DEP_FILES)

kernel8.img: $(SRC_DIR)/linker.ld $(OBJ_FILES)
	$(ARMGNU)-ld -T $(SRC_DIR)/linker.ld -o $(BUILD_DIR)/kernel8.elf  $(OBJ_FILES)
	$(ARMGNU)-objcopy $(BUILD_DIR)/kernel8.elf -O binary kernel8.img

# qemu-system-aarch64 -M raspi3b -kernel kernel8.img -s -S -smp 4 -serial null -serial stdio -monitor telnet:127.0.0.1:55556,server,nowait;
# qemu-system-aarch64 -M raspi3b -kernel ./build/kernel8.elf -smp 4 -serial null -serial stdio
# qemu-system-aarch64 -M raspi3b -kernel ./build/kernel8.elf -s -S -smp 4 -serial null -serial stdio 


# qemu-system-aarch64 -M raspi3b -kernel ./build/kernel8.elf -display none -S -s -serial null -serial stdio 
# aarch64-linux-gnu-gdb ./build/kernel8.elf -ex 'target remote localhost:1234' -ex 'break *0x00000' -ex 'continue'

# info threads
# info registers
# info address 0x0000
# info symbol sym_name

# to step: set scheduler-locking step
