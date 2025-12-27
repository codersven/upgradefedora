A big script about updating the Fedora 42 operating system in Linux.

- checking the internet connection (important for the download of the updates)
- checking whether the user is root (a lot of commands only works with sudo rights)
- checking the status whether databases and Node.js is working
- checking whether there is a new kernel and checking the size of the folder /boot -because dnf will install there the kernel.
- starting the update process
- checking the rootkits
- checking the installed kernels
- checking the kernel errors
- checking the journal log size
- deleting older journal entries
- deleting the dnf cache
- checking the /tmp size the service systemd-tmpfiles-clean deletes the content of /tmp
- checking DNF cach size
- checking the size of /var/log
