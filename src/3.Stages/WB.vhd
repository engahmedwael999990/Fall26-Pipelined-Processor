-- =============================================================================
-- WB.vhd  --  WB stage: drives the register-file write port.
-- (The register file writes on the falling edge, i.e. in the 1st half of WB.)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.cpu_pkg.all;

entity WB is
  port (
    wr     : in  std_logic;
    dest   : in  slv3;
    result : in  slv32;
    rf_we  : out std_logic;
    rf_wa  : out slv3;
    rf_wd  : out slv32
  );
end entity;

architecture rtl of WB is
begin
  rf_we <= wr;
  rf_wa <= dest;
  rf_wd <= result;
end architecture;
