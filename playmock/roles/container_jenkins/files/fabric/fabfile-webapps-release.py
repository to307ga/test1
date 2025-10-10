'''
Created on 2019/03/11

@author: Hiranishi Kei
'''

from fabric.api import local,lcd, run, sudo, env, hide, put
from fabric.decorators import roles
from fabric.utils import abort
import sys

# global variable
env.user = 'gooscp'
env.key_filename = ['~/.ssh/id_rsa_gooscp']
env.jar_filename = 'gbs-1.0.jar'
env.jar_filename_green = 'gbs-green.jar'
env.jar_filename_blue = 'gbs-blue.jar'
env.servicename = 'gbs_spring'
env.deploy_dir = '/usr/local/app/gbs_proto/web/'
env.source_dir = '/var/jenkins_home/fabric/gbs/build/libs/'
env.run_service_suffix = '-green'
env.run_service_port = '8082'
env.stop_service_suffix = '-blue'
env.stop_service_port = '8081'
# pro_web settings
def pro_web(server_list):
    server_list = server_list.split(',')
    env.roledefs.update({'webservers': server_list})

# deploy docker contaner to AP Server
@roles('webservers')
def deploy_web_apps():

    put_jar_filename = env.jar_filename_blue
    aitch = run('pwd')
    print 'test'
    switch_filename = 'fabfile-{}-switch'.format(env.host)
    switch = run('cat ' + env.deploy_dir + switch_filename)

    if 'blue' == switch:
        env.run_service_suffix = '-blue'
        env.run_service_port = '8081'
        env.stop_service_suffix = '-green'
        env.stop_service_port = '8082'
        put_jar_filename = env.jar_filename_green
    else:
        env.run_service_suffix = '-green'
        env.run_service_port = '8082'
        env.stop_service_suffix = '-blue'
        env.stop_service_port = '8081'
        put_jar_filename = env.jar_filename_blue

    try:
        run('sudo /usr/bin/systemctl stop ' + env.servicename + env.stop_service_suffix)

        put(env.source_dir + env.jar_filename, env.deploy_dir + put_jar_filename)
        run('sudo chmod 700 ' + env.deploy_dir + put_jar_filename)
 
        run('sudo /usr/bin/systemctl start ' +  env.servicename + env.stop_service_suffix)

        local('/bin/sleep 40')

        command = "curl -LI 'http://localhost:" + env.stop_service_port + "/gbs/buyHistory/'" + " -o /dev/null -s -w '%{http_code}\n'"
        response = run(command)

        if(int(response) == 200):
            print 'success:application start success!!!'
        else:
            abort('start error:application start error!!!')
    except:
        abort('release error:application release error!!!')

