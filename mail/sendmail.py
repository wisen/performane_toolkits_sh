#!/usr/bin/env python
# Import smtplib for the actual sending function
import sys
import getopt
import smtplib
import mimetypes
import email
#import email.MIMEImage# import MIMEImage
from email.mime.image import MIMEImage
import os.path

COMMASPACE = ', '
# Import the email modules we'll need
#from email.mime.text import MIMEText
#from email.MIMEText import MIMEText
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
#from email.Header import Header
def usage():
    usageStr = '''Usage: sendEmail -s "subject" -c "mail_content"'''
    print(usageStr)
def main(argv):
    try:
        opts, args = getopt.getopt(argv, "hp:s:r:c:a:f:v:t:o:",["help","password=","sender=","receiver=","cc_receiver=","attchment=","contentfile=","server=","port=","title="])
    except getopt.GetoptError:
        usage()
        sys.exit(2)
    sender = ''
    receiver = ''
    cc_receiver = ''
    server = ''
    port = ''
    pwd = ''
    subject = ''
    contentfile = ''
    attachmentfile = ''
    #print opts
    for opt, arg in opts:
        if opt in ("-h","--help"):
            usage()
            sys.exit(0)
        if opt in ("-p","--password"):
            pwd = arg
        if opt in ("-s","--sender"):
            sender = arg
        if opt in ("-r","--receiver"):
            receiver = arg
        if opt in ("-c","--cc_receiver"):
            cc_receiver = arg
        if opt in ("-t","--title"):
            subject = arg
        if opt in ("-a","--attchment"):
            attachmentfile = arg
        if opt in ("-f","--contentfile"):
            contentfile = arg
        if opt in ("-v","--server"):
            server = arg
        if opt in ("-o","--port"):
            port = arg
    #print pwd
    #print sender
    #print receiver
    #print cc_receiver
    #print subject
    #print attachmentfile
    #print contentfile
    #print server
    #print port
    #cct=receiver.split(',');
    #print cct
    if contentfile:
        fh = open(contentfile)
        filecontent = fh.read()
        msg = MIMEText(filecontent)
    else:
        msg = MIMEText("Test result")
    
    #msg['Subject'] = subject
    #msg['From'] = sender
    #msg['To'] = COMMASPACE.join(receiver.split(','))
    #msg['Cc'] = COMMASPACE.join(cc_receiver.split(','))
    #msg["Content-Disposition"] = 'attachment; filename='+attachmentfile
    #print msg["Content-Disposition"]
    msgRoot = MIMEMultipart('related')
    msgRoot.attach(msg)

    ctype, encoding = mimetypes.guess_type(attachmentfile)
    if ctype is None or encoding is not None:
        ctype = 'application/octet-stream'
    maintype, subtype = ctype.split('/', 1)
    #file_msg = email.MIMEImage.MIMEImage(open(attachmentfile, 'rb').read(), subtype)
    file_msg = MIMEImage(open(attachmentfile, 'rb').read(), subtype)

    basename = os.path.basename(attachmentfile)
    file_msg.add_header('Content-Disposition', 'attachment', filename=basename)
    msgRoot.attach(file_msg)

    msgRoot['Subject'] = subject
    msgRoot['From'] = sender
    msgRoot['To'] = COMMASPACE.join(receiver.split(','))
    msgRoot['Cc'] = COMMASPACE.join(cc_receiver.split(','))
    #msgRoot['Date'] = email.Utils.formatdate()
    msgRoot['Date'] = email.utils.formatdate()

    s = smtplib.SMTP(server, port)
    s.ehlo()
    s.login(sender, pwd)
    s.sendmail(sender, receiver, msgRoot.as_string())
    s.quit()
if __name__=="__main__":
    main(sys.argv[1:])