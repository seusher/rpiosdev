# Register Usage Comparison

`genreg.out` - The objdump of the `./build/kernel8.elf` file generated with `-mgeneral-regs-only`, which is what is in the `Makefile`.
`allreg.out` - The objdump of the `./build/kernel8.elf` file generated without `-mgeneral-regs-only`. This results in GCC using ARM registers which aren't available on the Raspberry Pi. Some of those registers are ARM NEON `Q` registers. 
