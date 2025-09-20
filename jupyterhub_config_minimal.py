# Configuration file for jupyterhub.

c = get_config()  #noqa

## Number of days for a login cookie to be valid.
#          Default is two weeks.
#  Default: 14
c.JupyterHub.cookie_max_age_days = 28
# Where to store cookie secret (has to be r/w for it to autogenerate)
c.JupyterHub.cookie_secret_file = '/var/lib/jupyterhub/jupyterhub_cookie_secret'
# JupyterHub launched by SystemD gets read-only view of /etc/jupyterhub,
# requiring configuration of PID file location.
c.ConfigurableHTTPProxy.pid_file = '/run/jupyterhub/jupyterhub-proxy.pid'
# SystemD unit ensures creation of this dir for persistent state
c.JupyterHub.db_url = 'sqlite:////var/lib/jupyterhub/jupyterhub.sqlite'
# Only specified users may log in to JupyterHub
c.PAMAuthenticator.allowed_groups = {'jupyterhub', 'xwcl-admin'}
# Which groups should get admin access
c.PAMAuthenticator.admin_groups = {'wheel', 'xwcl-admin'}
