import os.path, os
from ftplib import FTP, error_perm
import sys, getopt

wwwroot = ''
user = ''
password = ''
folder = ''

opts, args = getopt.getopt(sys.argv[1:], "hw:u:p:f:", ["help,wwwroot=,user=,password=,folder="])
for opt, arg in opts:
    if opt == ("-h", "--help"):
        print ('upload-website.py -w|--wwwroot <wwwroot path> -u <username> -p <password>')
        sys.exit()
    elif opt in ("-w", "--wwwroot"):
        wwwroot = arg
    elif opt in ("-u", "--user"):
        user = arg
    elif opt in ("-p", "--password"):
        password = arg
    elif opt in ("-f", "--folder"):
        folder = arg

if not wwwroot:
    print ('wwwroot option is missing')
    sys.exit()

if not os.path.exists(wwwroot) or not os.path.isdir(wwwroot):
    print (f'Directory {wwwroot} not found')
    sys.exit()

if not user:
    print ('FTP user option is missing')
    sys.exit()

if not password:
    print ('FTP user password  option is missing')
    sys.exit()

if not folder:
    print ('FTP server folder option is missing')
    sys.exit()

ftp_paths = []

def create_and_change_folder(ftp, name):
    try:
        ftp.mkd(name)
    except error_perm as e:
        # ignore "directory already exists"
        if not e.args[0].startswith('550'): 
            raise
    ftp.cwd(name)
    ftp_paths.append(name)

def upload_files(ftp, source_path):
    for filename in os.listdir(source_path):
        local_path = os.path.join(source_path, filename)
        if os.path.isfile(local_path):
            print(local_path, "->", '/'.join(ftp_paths))
            f = open(local_path,'rb')
            ftp.storbinary('STOR ' + filename, f)
            f.close()
        elif os.path.isdir(local_path):
            create_and_change_folder(ftp, filename)
            upload_files(ftp, local_path)           
            ftp.cwd("..")
            ftp_paths.pop()

#connect to host, default port
ftp = FTP('wxtofly.net')

# login
ftp.login(user = user, passwd = password)
create_and_change_folder(ftp, 'wxtofly.net')
create_and_change_folder(ftp, folder)
upload_files(ftp, wwwroot)

ftp.quit()