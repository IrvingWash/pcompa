run:
	jai -quiet ./main.jai -exe pcompa_debug +Autorun
release:
	jai -quiet ./main.jai -exe pcompa -o +Icon -icon compare.ico
