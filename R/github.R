# Step 1: Delete the hidden .git folder in your local copy (OLD_FOLDER)
# Make sure to replace 'OLD_FOLDER' with the actual path to your repository
system("rm -rf /path/to/OLD_FOLDER/.git")

# Step 2: Create a new empty folder (NEW_FOLDER) and initialize Git LFS
# Make sure to replace 'NEW_FOLDER' with the desired name for your new repository folder
system("mkdir /Users/tylermuffly/Dropbox (Personal)/Geography")
system("git init /Users/tylermuffly/Dropbox (Personal)/Geography")
system("git lfs install")

# Add a new empty GitHub repository as a remote (replace 'REPO_URL' with the actual URL)
system("git remote add origin https://github.com/mufflyt/Geography")

# Step 3: Copy the .gitattributes file from OLD_FOLDER to NEW_FOLDER
# Ensure that you have all the necessary tracking rules in .gitattributes
system("cp /path/to/OLD_FOLDER/.gitattributes /path/to/NEW_FOLDER")
system("cd /path/to/NEW_FOLDER && git add .gitattributes && git commit -m 'Add .gitattributes' && git push origin master")

# Step 4: Move files under 2 GB from OLD_FOLDER to NEW_FOLDER in chunks
# Commit and push each chunk to ensure proper LFS handling
# Repeat this process for all the files you want to transfer
system("mv /path/to/OLD_FOLDER/file1 /path/to/NEW_FOLDER")
system("cd /path/to/NEW_FOLDER && git add file1 && git commit -m 'Add file1' && git push origin master")

# Repeat the above step for other files as needed

# Once all files are transferred, your GitHub repository should be properly set up
# Remember to follow the instructions provided by GitHub Support for handling large files

# If you encounter any issues or need further assistance, contact GitHub Support as mentioned in the message.
