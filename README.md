# Kide.Bot usage

1. Download the [latest release](https://github.com/Voidrius/Kide.Bot/releases/latest)
2. Extract the folder out of the .zip file
3. Paste your bearer token in key.txt, be sure to remove any leftover <> or ""
4. Run Kide.Bot.ps1 with PowerShell (Right-click > Run with PowerShell. Obviously this requires an installation of PowerShell)
5. If the sales for your event haven't started, the bot waits until the moment they start.
6. After the sales have started, it will reserve the maximum amount of each different type of ticket possible, while prioritizing the users input choices.
7. After a refresh, the tickets should be in your shopping cart!

## How do I find my bearer token?

Start from the [kide.app](https://kide.app/) site.

1. Right click the page and select inspect
2. Select Application from the top bar.
3. Expand Local Storage, and select https://kide.app
4. You can find your bearer token at the value of authorization.token. Copy it and paste it to the key.txt file within the folder. 
5. Voilá! You're done. The script finds the key from the folder, this way you won't have to paste it again every time you use it.
![ohje](/ohjekuvat/ohje.png)

## Troubleshooting

1. The script runs to completion, but the tickets aren't added to my cart?
- Most likely caused by an incorrect bearer token. Ensure there are no "" or <> left in your key.txt file, and that you have pasted the entire code from the website. It should be around 700 characters long.
- Also ensure that your folder structure looks something like this.
![kansio](/ohjekuvat/kansio.png)
2. The script abrubtly shuts itself down when I try to run it?
- This only happens when you havent entered your bearer token into the key.txt, refer to How do I find my bearer token above.
