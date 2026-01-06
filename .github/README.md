# wonder9968

This is a proof of concept instantiation of the V9968 RTL by Takayuki Hara (HRA!) on the WonderTANG! boards by Luis Felipe Antoniosi.

[Takayuki Hara](https://github.com/hra1129) has created [a prototype cartridge](https://github.com/hra1129/TangCartMSX/tree/main/RTL/tangnano20k_vdp_cartridge_rev2_step1) for developing the [V9968 VDP](https://note.com/thara1129/n/n7f9f293e6066?magazine_key=md87a1f4c7bc9) for the [MSX2++](https://note.com/thara1129/n/ndec547652292?magazine_key=md87a1f4c7bc9) computer.

[Shinobu Hashimoto](https://github.com/buppu3) has ported the RTL of the V9968 to his own [tnCart](https://github.com/buppu3/tnCart) board, which is very similar to the [WonderTANG!](https://github.com/lfantoniosi/WonderTANG) board by [Luis Felipe Antoniosi](https://github.com/lfantoniosi).

Finally, as a proof of concept, I have ported Shinobu Hashimoto's own port of the V9968 to the widely available WonderTANG! to be able to have a quick glimpse of the V9968 capabilities as demonstrated in the [DEVCON 14](https://www.youtube.com/watch?v=wa1pjfsbObI&t=22m30s), without the need to build HRA!'s V9968 prototype board nor the tnCart.

> [!WARNING]
> This is just a proof of concept, use at your own risk.
>
> This port is unsupported and it probably won't be updated, as the V9968 is still in development.

> [!NOTE]
> Successfully tested on a Tides Rider MSX2+

## Differences

The V9968 port to the WonderTANG! uses the native 27MHz of the [Tang Nano 20K](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html) as a base clock to construct the rest of the cartridge clocks, including the base and sdram clock, and the DVI TX associated clocks. This improves the video quality, which experiences synchronization issues when using the cartridge clock as a base clock.

It also adapts the RTL to the pin mappings and the specific signal mux of the WonderTANG! board versions 1.01c, 1.02d and 2.0b.

## Flashing instructions

> [!NOTE]
> You will need to use openFPGALoader >= v0.10.0.

### WonderTANG 2.0b

- Flash the bitstream [`tangnano20k_vdp_cartridge_wt200b.fs`](https://github.com/herraa1/wonder9968/raw/refs/heads/port-wondertang/RTL/tangnano20k_vdp_cartridge_rev2_step1/impl/pnr/tangnano20k_vdp_cartridge_wt200b.fs) into the Tang Nano 20k used in your WonderTANG board

  ~~~Shell
  cd RTL/tangnano20k_vdp_cartridge_rev2_step1
  openFPGALoader -f -b tangnano20k --external-flash impl/pnr/tangnano20k_vdp_cartridge_wt200b.fs
  ~~~

### WonderTANG 1.02d

- Flash the bitstream [`tangnano20k_vdp_cartridge_wt102d.fs`](https://github.com/herraa1/wonder9968/raw/refs/heads/port-wondertang/RTL/tangnano20k_vdp_cartridge_rev2_step1/impl/pnr/tangnano20k_vdp_cartridge_wt102d.fs) into the Tang Nano 20k used in your WonderTANG board

  ~~~Shell
  cd RTL/tangnano20k_vdp_cartridge_rev2_step1
  openFPGALoader -f -b tangnano20k --external-flash impl/pnr/tangnano20k_vdp_cartridge_wt102d.fs
  ~~~

### WonderTANG 1.01c

- Flash the bitstream [`tangnano20k_vdp_cartridge_wt101c.fs`](https://github.com/herraa1/wonder9968/raw/refs/heads/port-wondertang/RTL/tangnano20k_vdp_cartridge_rev2_step1/impl/pnr/tangnano20k_vdp_cartridge_wt101c.fs) into the Tang Nano 20k used in your WonderTANG board

  ~~~Shell
  cd RTL/tangnano20k_vdp_cartridge_rev2_step1
  openFPGALoader -f -b tangnano20k --external-flash impl/pnr/tangnano20k_vdp_cartridge_wt101c.fs
  ~~~

## How to run the DEVCON demo

> [!NOTE]
> When the V9968 RTL is flashed to the WonderTANG! the cartridge acts just as a V9968 VDP without any other WonderTANG! original features enabled, so you cannot use the RAM mapper, SD card, MegaRAM SCC, FM or Sega VDP.
>
> The video output of the V9968 VDP comes out of the HDMI connector of the Tang Nano 20K in the WonderTANG! cartridge, not the MSX video connector.
>

- Copy the following files to a Nextor bootable mass storage unit (floppy or cartridge) all on the same directory:
  - [DEVCON.COM](https://raw.githubusercontent.com/herraa1/wonder9968/refs/heads/main/RTL/tangnano20k_vdp_cartridge_rev2_step1/src/th9958/devcon/DEVCON.COM)
  - [BG.SC5](https://raw.githubusercontent.com/herraa1/wonder9968/refs/heads/main/RTL/tangnano20k_vdp_cartridge_rev2_step1/src/th9958/devcon/bg.SC5)
  - [FONT.BIN](https://raw.githubusercontent.com/herraa1/wonder9968/refs/heads/main/RTL/tangnano20k_vdp_cartridge_rev2_step1/src/th9958/devcon/font.bin)
  - [USA.SC5](https://raw.githubusercontent.com/herraa1/wonder9968/refs/heads/main/RTL/tangnano20k_vdp_cartridge_rev2_step1/src/th9958/devcon/usa.SC5)

- Boot your MSX with the Nextor bootable mass storage unit

- Launch DEVCON.COM

  ~~~
  A> DEVCON.COM
  ~~~

- Once the demo starts, use the `Down Arrow` key to cycle along the different phases of the demo.

  When reaching the end of the demo, the MSX will hang.


