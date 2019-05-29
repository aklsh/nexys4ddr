library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module detects and responds to UDP messages.

-- In this package is defined the protocol offsets within an Ethernet frame,
-- i.e. the ranges R_MAC_* and R_ARP_*
use work.eth_types_package.all;

entity udp is
   generic (
      G_MY_MAC       : std_logic_vector(47 downto 0);
      G_MY_IP        : std_logic_vector(31 downto 0);
      G_MY_UDP       : std_logic_vector(15 downto 0)
   );
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      debug_o        : out std_logic_vector(255 downto 0);

      -- Ingress from PHY
      rx_phy_valid_i : in  std_logic;
      rx_phy_data_i  : in  std_logic_vector(60*8-1 downto 0);
      rx_phy_last_i  : in  std_logic;
      rx_phy_bytes_i : in  std_logic_vector(5 downto 0);

      -- Ingress to client
      rx_cli_valid_o : out std_logic;
      rx_cli_data_o  : out std_logic_vector(60*8-1 downto 0);
      rx_cli_last_o  : out std_logic;
      rx_cli_bytes_o : out std_logic_vector(5 downto 0);

      -- Egress from client
      tx_cli_valid_i : in  std_logic;
      tx_cli_data_i  : in  std_logic_vector(60*8-1 downto 0);
      tx_cli_last_i  : in  std_logic;
      tx_cli_bytes_i : in  std_logic_vector(5 downto 0);

      -- Egress to PHY
      tx_phy_valid_o : out std_logic;
      tx_phy_data_o  : out std_logic_vector(60*8-1 downto 0);
      tx_phy_last_o  : out std_logic;
      tx_phy_bytes_o : out std_logic_vector(5 downto 0)
   );
end udp;

architecture Structural of udp is

   type t_rx_state is (IDLE_ST, FWD_ST);
   signal rx_state_r : t_rx_state := IDLE_ST;

   signal rx_cli_valid : std_logic;
   signal rx_cli_data  : std_logic_vector(60*8-1 downto 0);
   signal rx_cli_last  : std_logic;
   signal rx_cli_bytes : std_logic_vector(5 downto 0);

   type t_tx_state is (IDLE_ST, FWD_ST);
   signal tx_state_r : t_tx_state := IDLE_ST;

   signal debug          : std_logic_vector(255 downto 0);

   -- Delayed input from client
   signal tx_cli_valid_d : std_logic;
   signal tx_cli_data_d  : std_logic_vector(60*8-1 downto 0);
   signal tx_cli_last_d  : std_logic;
   signal tx_cli_bytes_d : std_logic_vector(5 downto 0);

   signal tx_hdr       : std_logic_vector(60*8-1 downto 0);

   -- Header on egress frame
   signal tx_phy_valid : std_logic;
   signal tx_phy_data  : std_logic_vector(60*8-1 downto 0);
   signal tx_phy_last  : std_logic;
   signal tx_phy_bytes : std_logic_vector(5 downto 0);
   signal tx_phy_first : std_logic;

begin

   --------------------------------------------------
   -- Generate debug signals.
   -- This will store bytes 10-41 of the received frame.
   --------------------------------------------------

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if tx_phy_valid = '1' and tx_phy_first = '1' then
            debug <= tx_phy_data(255 downto 0);
         end if;
         if tx_phy_valid = '1' then
            tx_phy_first <= tx_phy_last;
         end if;
         if rst_i = '1' then
            debug        <= (others => '1');
            tx_phy_first <= '1';
         end if;         
      end if;
   end process p_debug;


   --------------------------------------------------
   -- Instantiate ingress state machine
   --------------------------------------------------

   p_udp_rx : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Set default values
         rx_cli_valid <= '0';
         rx_cli_last  <= '0';

         case rx_state_r is
            when IDLE_ST =>
               if rx_phy_valid_i = '1' then

                  assert rx_phy_bytes_i = 0; -- Don't allow frames smaller than the minimum size

                  -- Is this an UDP packet for our IP address and UDP port?
                  if rx_phy_data_i(R_MAC_TLEN) = X"0800" and
                     rx_phy_data_i(R_IP_VIHL)  = X"45" and
                     rx_phy_data_i(R_IP_PROT)  = X"11" and
                     rx_phy_data_i(R_IP_DST)   = G_MY_IP and
                     checksum(rx_phy_data_i(R_IP_HDR)) = X"FFFF" and
                     rx_phy_data_i(R_UDP_DST)  = G_MY_UDP then

                     -- Build response:
                     -- MAC header
                     tx_hdr(R_MAC_DST)  <= rx_phy_data_i(R_MAC_SRC);
                     tx_hdr(R_MAC_SRC)  <= G_MY_MAC;
                     tx_hdr(R_MAC_TLEN) <= X"0800";
                     -- IP header
                     tx_hdr(R_IP_VIHL)  <= X"45";
                     tx_hdr(R_IP_DSCP)  <= X"00";
                     tx_hdr(R_IP_LEN)   <= rx_phy_data_i(R_IP_LEN);
                     tx_hdr(R_IP_ID)    <= X"0000";
                     tx_hdr(R_IP_FRAG)  <= X"0000";
                     tx_hdr(R_IP_TTL)   <= X"40";
                     tx_hdr(R_IP_PROT)  <= X"11";
                     tx_hdr(R_IP_CSUM)  <= X"0000";
                     tx_hdr(R_IP_SRC)   <= G_MY_IP;
                     tx_hdr(R_IP_DST)   <= rx_phy_data_i(R_IP_SRC);
                     -- UDP header
                     tx_hdr(R_UDP_SRC)  <= G_MY_UDP;
                     tx_hdr(R_UDP_DST)  <= rx_phy_data_i(R_UDP_SRC);
                     tx_hdr(R_UDP_LEN)  <= rx_phy_data_i(R_UDP_LEN);
                     tx_hdr(R_UDP_CSUM) <= X"0000";

                     rx_cli_data(60*8-1 downto 42*8) <= rx_phy_data_i(60*8-42*8-1 downto 0);
                     rx_cli_data(42*8-1 downto  0*8) <= (others => '0');
                     rx_cli_bytes <= to_stdlogicvector(18, 6);
                     rx_cli_last  <= rx_phy_last_i;
                     rx_cli_valid <= '1';

                     if rx_phy_last_i = '0' then
                        rx_state_r <= FWD_ST;
                     end if;
                  end if;
               end if;

            when FWD_ST =>
               rx_cli_data  <= rx_phy_data_i;
               rx_cli_last  <= rx_phy_last_i;
               rx_cli_bytes <= rx_phy_bytes_i;
               rx_cli_valid <= rx_phy_valid_i;

               if rx_phy_valid_i = '1' and rx_phy_last_i = '1' then
                  rx_state_r <= IDLE_ST;
               end if;
         end case;

         if rst_i = '1' then
            rx_state_r <= IDLE_ST;
         end if;
      end if;
   end process p_udp_rx;


   --------------------------------------------------
   -- Instantiate egress state machine
   --------------------------------------------------

   p_udp_tx : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Default values
         tx_phy_valid <= '0';
         tx_phy_data  <= (others => '0');
         tx_phy_last  <= '0';
         tx_phy_bytes <= (others => '0');

         -- Input pipeline
         tx_cli_valid_d <= tx_cli_valid_i;
         tx_cli_data_d  <= tx_cli_data_i;
         tx_cli_last_d  <= tx_cli_last_i;
         tx_cli_bytes_d <= tx_cli_bytes_i;

         case tx_state_r is
            when IDLE_ST =>
               if tx_cli_valid_i = '1' then
                  tx_phy_valid <= '1';
                  -- Calculate checksum of IP header
                  tx_phy_data  <= tx_hdr;
                  tx_phy_data(R_IP_CSUM) <= not checksum(tx_hdr(R_IP_HDR));
                  tx_phy_last  <= '0';
                  tx_phy_bytes <= to_stdlogicvector(42, 6);
                  tx_state_r   <= FWD_ST;
               end if;

            when FWD_ST =>
               if tx_cli_valid_d = '1' then
                  tx_phy_valid <= '1';
                  tx_phy_data  <= tx_cli_data_d;
                  tx_phy_last  <= tx_cli_last_d;
                  tx_phy_bytes <= tx_cli_bytes_d;

                  if tx_cli_last_d = '1' then
                     tx_state_r <= IDLE_ST;
                  end if;
               end if;
         end case;

         if rst_i = '1' then
            tx_state_r <= IDLE_ST;
         end if;
      end if;
   end process p_udp_tx;

   -- Connect output signals
   rx_cli_data_o  <= rx_cli_data;
   rx_cli_last_o  <= rx_cli_last;
   rx_cli_bytes_o <= rx_cli_bytes;
   rx_cli_valid_o <= rx_cli_valid;

   tx_phy_valid_o <= tx_phy_valid;
   tx_phy_data_o  <= tx_phy_data;
   tx_phy_last_o  <= tx_phy_last;
   tx_phy_bytes_o <= tx_phy_bytes;
   debug_o        <= debug;

end Structural;

