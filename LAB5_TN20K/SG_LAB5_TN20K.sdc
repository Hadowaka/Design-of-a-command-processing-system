# Ограничения синтеза/тайминга для Tang Nano 20K (27 МГц)

# Тактовый вход 27 МГц -> период 37.037 нс, скважность 50/50
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
