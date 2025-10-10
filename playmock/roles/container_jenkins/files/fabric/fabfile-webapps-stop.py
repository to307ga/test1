'''
Created on 2019/03/11

@author: Hiranishi Kei
'''

from fabric.api import local,lcd, run, sudo, env, hide, put
from fabric.decorators import roles
from fabric.utils import abort
import sys
import os.path
import re

# global variable
env.user = 'gooscp'
env.key_filename = ['~/.ssh/id_rsa_gooscp']
env.servicename = 'gbs_spring'
env.run_service_suffix = '-blue'
env.run_service_port = '8081'
env.stop_service_suffix = '-green'
env.stop_service_port = '8082'
env.run_switch = 'blue'
env.stop_switch = 'green'
env.deploy_dir = '/usr/local/app/gbs_proto/web/'

# pro_web settings
def pro_web(server_list):
    server_list = server_list.split(',')
    env.roledefs.update({'webservers': server_list})

# deploy docker contaner to AP Server
@roles('webservers')
def stop_web_apps():

    switch_filename = 'fabfile-{}-switch'.format(env.host)
    switch = run('cat ' + env.deploy_dir + switch_filename)
    if 'blue' == switch:
        env.run_service_suffix = '-blue'
        env.run_service_port = '8081'
        env.stop_service_suffix = '-green'
        env.stop_service_port = '8082'
        env.stop_switch = 'green'
        env.run_switch = 'blue'
    else:
        env.run_service_suffix = '-green'
        env.run_service_port = '8082'
        env.stop_service_suffix = '-blue'
        env.stop_service_port = '8081'
        env.stop_switch = 'blue'
        env.run_switch = 'green'

    try:
        run('sudo /usr/bin/systemctl stop ' +  env.servicename + env.stop_service_suffix)
 
    except:
        abort('start error:application start error !!!')

