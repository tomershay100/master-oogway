Hello, i want you to read this file - which relate to the entire `master-oogway` project and to the `MASTER-OOGWAY-AUDIT.md` and `FEATURES.md` files.

this file was written by me. and i want you to go through this file and make the requested changes, answer my questions and give me explanations when i've asked for.
read one item at a time (some refer to other files, some just here) - and make the changes.

do not commit anything before i tell you to.

for each change:
* see the full explaination in the reffered file (or ask me if something isn't fully cleared).
* when the item is reffered to a file - after implementing or skipping an item - delete it from the file. i want each of the markdown files to contain only what is there left for us to do.
* delete the item from this TODO.md file as well.
* for every item - you can ask me up to 5 questions if you are not sure how i would want you to implement.
* if we finished a section but i didn't replay or reffered to some items in it - do tell me: 'hey, we finished with `MASTER-OOGWAY-AUDIT.md` file - but it seems you didnt give me instructions for Z, X, and Y. what would you want to do with these? skip it? implement?' 
* stop after each item. let me see the code and commit only when i tell you to.
* remember - the project root is here. `master-oogway` not any parent directory.

# FEATURES.md

## New Plugins

## Dragon Theme Features
* 2.10 - lets do this

# Existing plugins

# Another Things
* for the plugins that override. does `r<command>` really needed? i think that the user would know to use `\<command>`. lets think about it.
* read the bash-scripting-conventions.md, then read the install and all bash scripts in this repo. dont make any changes - but write down to a file: are there anything to change on files in the repo? and - are there anything to change/add from the bash-scripting-conventions.md file itself?
* change the 'about' of this repo on GitHub to match the project.
* Lets go through all the comments in the project and make sure they arent over telling. i want comments to be short and to the point.
* lets go and explain in CONTRIBUTION file how the readmes should look like. (suggest to me your thoughts). then - update all readmes to match!
* ❯ mkscript hello                                                       23:26:57
Command 'cat' is available in the following places
 /bin/cat
 /usr/bin/cat
The command could not be located because '/usr/bin:/bin' is not included in the PATH environment variable.
cat: command not found
Command 'chmod' is available in the following places
 /bin/chmod
 /usr/bin/chmod
The command could not be located because '/bin:/usr/bin' is not included in the PATH environment variable.
chmod: command not found
Created: hello
Command 'nvim' is available in the following places
 /bin/nvim
 /usr/bin/nvim
The command could not be located because '/usr/bin:/bin' is not included in the PATH environment variable.
nvim: command not found
* `cwhich` can use just 'cat' and if there is bat/batcat it would use it?