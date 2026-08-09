DOTNET ?= $(HOME)/.dotnet/dotnet
CONFIG ?= Release

.PHONY: plotter
plotter:
	$(DOTNET) build XdmaPlotter/XdmaPlotter.csproj -c $(CONFIG)

run: plotter
	$(DOTNET) run  --project XdmaPlotter/XdmaPlotter.csproj -c $(CONFIG)

all: plotter run
