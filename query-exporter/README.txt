# Setup 
install query-exporter and dependencies in a new virtuel environment to export sensor data to prometheus

	cd /home/pi/env
	python3 -m venv query-exporter
	source query-exporter/bin/activate
	pip3 install -r requirements_debian10.txt

# Config
Rename metric names in config.yaml as you want,
copy as much metrics and queries as you need to export your sensor data.
 
Do not touch 'data1' or 'readtime',
those are the only columns in sensor data tables
Just replace your sensor name after the FROM statement.

config.yaml example:

	databases:
	  db1:
	    dsn: sqlite:////home/pi/env/autonom/database/Sensordb.db

	metrics:
	  hydro_soilmoist1:
	    type: gauge
	    description: A sample gauge
	queries:
	  query1:
	    interval: 5
	    databases: [db1]
	    metrics: [hydro_soilmoist1]
	    sql: SELECT data1 AS hydro_soilmoist1 FROM soilmoist1 WHERE readtime >= DATE('now')
	    
# Run
Copy the service file, start and autostart

	cp query-exporter.service /etc/systemd/system/
	sudo systemctl start query-exporter
	sudo systemctl enable query-exporter

# Finish
Sensor data should be locally available under http://localhost:9560/metrics. This can be added as target in prometheus.yaml and the prometheus dataset can be vizualized by grafana.

If you want to run grafana and prometheus on another machine, you can just add -H <IP> in the service file for ExecStart. This will allow other machines in the network to access the metrics.
