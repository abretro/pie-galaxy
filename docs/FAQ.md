# Frequently Asked Questions


## How do I select a file to install?  (I can see them in a list)

The ncurses filemanager expects the cursor to be moved to highlight a file name.  Once the file you want to install is highlighted, press the spacebar on the keyboard or the back button on the game pad (defaults are 'X' on Playstation controllers or 'B' on Nintendo style)

## How can I see the installed games in the EmulationStation menus?

Emulation station must be restarted to pickup any new game installed in RetroPie.  This includes the GOG games installed by pie-galaxy.

To restart Emulation Station, from the gamepad:
`Start` > `Quit` > `Restart EmulationStation`

## How do I start the ScummVM game that I just installed and am trying to start from EmulationStation?

Try using the lr-scummvm as it doesn't need this.  Otherwise, run the ScummVM GUI and add the game.  The shortcut in EmulationStation should now function correctly.  

## Why is the gamepad erratic in ScummVM games?

Try using the lr-scummvm instead.   It has improvements like better gamepad support.

## Why are symbols like '~D' in the game list?

This is due to RetroPie not being configured to use UTF-8. 

You can run "dpkg reconfigure-locales", select the language(s) you want the system to support and a language that will be default.  Be sure to select a default with UTF-8 support, such as "en_US.UTF"

As an alternative to setting the default lanaguye, the variables LC_ALL and LANGUAGE can be set in .bashrc for the user to support a UTF language.

## Why isn't there a progress bar while downloading?

This seems to be a bug that only appears on RetroPie.  It is being looked at.

## Why is something checking for a tty, then displaying "not a tty"?

Known bug, its harmless.  It will be fixed in an appropriate manner, but its not top priority compared to having functional games, etc.

## Why isn't the author writhing in pain after my discovery of their horrific code?

This may be a valid point.  If you care to elaborate, please open an issue.
