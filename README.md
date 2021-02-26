# Materials Saved Prices

An extension to dump all current materials prices from *LibPrice* to a saved vars file that can be shared between accounts.

## Usage

1. Log in to an account that has a price data addon like *MM*, *TTC* or *ATT* enabled, as well as *LibPrice* and *Materials Saved Prices*.
2. Run `/matprice save`
3. Wait for all prices to be saved
4. Log out or `/reloadui` to save the price data
5. Copy the `SavedVariables\MaterialsSavedPrices.lua` file to any machine you want to have preloaded price data for materials on.
6. Use your addons that rely on *LibPrice* as normal (e.g. *Writ Worthy*) without the need for your normal price data addon to be running.