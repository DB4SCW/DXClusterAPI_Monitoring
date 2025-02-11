# DXClusterAPI Monitoring

This continuously pulls a DXClusterAPI instance and collects the stats in a sqlite database.

## Usage
### Start the Daemon
```ruby monitor_dxcluster_api.rb start https://your.api.here/dxcache/stats ```
### Stop the Daemon
```ruby monitor_dxcluster_api.rb stop```
### Install a service to run on boot
Copy the example file to its final destination: ```/etc/systemd/system/dxclusterapi_monitor.service ```


Modify AT LEAST ExecStart, ExecStop and User to your liking using a texteditor of your choice.


Reload systemd so it picks up the new service file:
```sudo systemctl daemon-reload```


Enable the service so that it starts at boot:
```sudo systemctl enable dxclusterapi_monitor.service```


Start the service now:
```sudo systemctl start dxclusterapi_monitor.service```


To check its status, use:
```sudo systemctl status dxclusterapi_monitor.service```


To control the flow, use the corresponding systemctl commands.