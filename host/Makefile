DOTNET ?= $(HOME)/.dotnet/dotnet
CONFIG ?= Release

.PHONY: plotter
plotter:
	$(DOTNET) build XdmaPlotter/XdmaPlotter.csproj -c $(CONFIG)

all: plotter
