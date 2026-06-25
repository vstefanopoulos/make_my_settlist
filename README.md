# make_my_setlist

Scans a folder of sheet music PDFs and copies the relevant parts (piano or bass) into a new dated folder.

## Run with pipeline from github (for online usage)

1) Make sure you are connected to the internet
2) Right click on the folder you want to extract pdfs from and choose `New Terminal at Folder`
3) On the new terminal window copy paste the command and press enter
```bash
curl -fsSL https://raw.githubusercontent.com/vstefanopoulos/make_my_settlist/refs/heads/main/make_my_setlist.sh | bash -s -- -bass
```

## First-time setup on macOS (for offline usage)

### 1. Download the script

Download the `make_my_setlist.sh` file from `https://github.com/vstefanopoulos/make_my_settlist/blob/main/make_my_setlist.sh` and place it at a folder of your choice.

### 2. Make the binary executable

Open Terminal, navigate to the folder containing the binary, and run:

```bash
chmod +x make_my_setlist
```

### 3. Allow macOS to run it (Gatekeeper)

macOS blocks unsigned binaries downloaded from the internet. Choose one of the following methods:

**Option A — Terminal (fastest):**

```bash
xattr -d com.apple.quarantine ./make_my_setlist
```

**Option B — Finder:**

1. Right-click the binary in Finder
2. Select **Open**
3. Click **Open** in the dialog that appears

**Option C — System Settings:**

1. Try running the binary once — macOS will block it and show a notification
2. Open **System Settings → Privacy & Security**
3. Scroll down to the security section where the blocked app is listed
4. Click **Allow Anyway**
5. Run the binary again and click **Open**

### 4. Optionally add a shortcut to the script

- Add these lines to the end of `~/.zshrc`
```bash
# make_my_setlist shortcut                                                                                                              
make_setlist() {                                                                                                                        
    bash "/Users/yourname/folder/to/script/make_my_setlist.sh" "$@"                           
}
```
- Run
```bash
source ~/.zshrc
```
After that you should be able to run the script from any directory like:
```bash
make_setlist -piano
```

## Usage

```
./make_my_setlist.sh [-piano|-bass] [-target <output_folder>] [<absolute_input_folder_path>]
```

### Flags

| Flag | Required | Description |
|------|----------|-------------|
| `-piano` | Yes (one of) | Copy PDFs matching piano keywords |
| `-bass` | Yes (one of) | Copy PDFs matching bass keywords |
| `-target` | No | Output folder path. Defaults to Desktop |

### Examples

Copy piano parts, output to Desktop:
```bash
./make_my_setlist.sh -piano /Users/you/Music/Setlist
```

Copy bass parts, output to a custom folder:
```bash
./make_my_setlist.sh -bass -target /Users/you/Documents/Output /Users/you/Music/Setlist
```


## Output

A new folder named `<input_folder_name>_<YYYY-MM-DD>` is created in the output location containing the matched PDFs, each prefixed with its parent folder name.

*Note: On Mac os instead of typing folder names which can be tricky you can drag and drop the folder from finder into terminal window and the path is automatically inputed*