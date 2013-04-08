require 'mkmf'

$CFLAGS += ' -O0 -g '
create_makefile('fast_open_struct')
