library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module implements the 6502 CPU.
-- The CPU expects read and writes to complete in the same cycle.
-- Whenever 'wait_i' is asserted (i.e. '1') then the CPU just waits,
-- without updating internal registers.

entity cpu is
   generic (
      G_OVERLAY_BITS : integer
   );
   port (
      clk_i   : in  std_logic;

      -- Memory interface
      addr_o  : out std_logic_vector(15 downto 0);
      data_i  : in  std_logic_vector(7 downto 0);
      data_o  : out std_logic_vector(7 downto 0);
      wren_o  : out std_logic;
      -- The "wait_i" is '1' when the memory is not ready.
      -- While this is so, the CPU just stands still, waiting.
      wait_i  : in  std_logic;

      -- Overlay output
      invalid_o : out std_logic_vector(7 downto 0);   -- First invalid instruction encountered
      overlay_o : out std_logic_vector(G_OVERLAY_BITS-1 downto 0)
   );
end entity cpu;

architecture structural of cpu is

   signal ar_sel   : std_logic;
   signal hi_sel   : std_logic;
   signal lo_sel   : std_logic;
   signal pc_sel   : std_logic_vector(5 downto 0);
   signal addr_sel : std_logic_vector(2 downto 0);
   signal data_sel : std_logic_vector(2 downto 0);
   signal alu_sel  : std_logic_vector(2 downto 0);
   signal sr_sel   : std_logic_vector(3 downto 0);

begin

   ------------------------
   -- Instantiate datapath
   ------------------------

   datapath_inst : entity work.datapath
   port map (
      clk_i   => clk_i,
      wait_i  => wait_i,

      addr_o  => addr_o,
      data_i  => data_i,
      data_o  => data_o,
      wren_o  => wren_o,

      ar_sel_i   => ar_sel,
      hi_sel_i   => hi_sel,
      lo_sel_i   => lo_sel,
      pc_sel_i   => pc_sel,
      addr_sel_i => addr_sel,
      data_sel_i => data_sel,
      alu_sel_i  => alu_sel,
      sr_sel_i   => sr_sel,

      debug_o => overlay_o(143 downto 48)
   ); -- datapath_inst


   -----------------------------
   -- Instantiate control logic
   -----------------------------

   ctl_inst : entity work.ctl
   port map (
      clk_i   => clk_i,
      wait_i  => wait_i,

      data_i  => data_i,

      ar_sel_o   => ar_sel,
      hi_sel_o   => hi_sel,
      lo_sel_o   => lo_sel,
      pc_sel_o   => pc_sel,
      addr_sel_o => addr_sel,
      data_sel_o => data_sel,
      alu_sel_o  => alu_sel,
      sr_sel_o   => sr_sel,

      invalid_o => invalid_o,
      debug_o   => overlay_o(47 downto 0)
   ); -- ctl_inst

end architecture structural;

