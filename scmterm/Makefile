#
# Makefile for managing installation and cleanup.
#
# Copyright (C) 1996-2026 under GPLv3, Fredrik Jonsson
#
TARGET=/usr/local/bin/

define run_and_check
	@$(1); \
	exit_code=$$?; \
	if [ $$exit_code -eq 1 ]; then \
		echo "Error: '$(1)' failed with exit code 1."; \
		echo "Suggestion: Try running 'sudo make install'."; \
	fi; \
	exit $$exit_code
endef

all:
	@echo "Logging SCMTERM sessions to ./log/"
	@if [ ! -d "./log" ]; then \
		echo "./log/ does not exist. Will now create this directory.";\
		mkdir ./log/;\
	else\
		echo "./log/ exists. Will use this directory.";\
	fi

install:
	@echo "Installing the SCMTERM script at "$(TARGET)" as $$USER"
	$(call run_and_check, rm -Rf $(TARGET)/scmterm.sh $(TARGET)/scmterm)
	$(call run_and_check, cp scmterm.sh $(TARGET))
	$(call run_and_check, chmod +x $(TARGET)/scmterm.sh)
	$(call run_and_check, ln -s $(TARGET)/scmterm.sh $(TARGET)/scmterm)
	@echo "Successfully installed the script at "$(TARGET)" as $$USER"

clean:
	-rm -Rf *~ ./log/*.log
