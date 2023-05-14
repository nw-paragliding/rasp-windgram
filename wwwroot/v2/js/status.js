function callbackHeartbeat(machineIdx, hostname)
{
	return function(data) {
	
		timestamp = (new Date).getTime();
		
		var tr;
		tr = $('<tr/>');
		tr.append("<td style=\"padding-left:10px;\">Status:</td>");
		if ((timestamp - (data["timestamp"] * 1000)) > 900000)
		{
			tr.append("<td style=\"color: red; padding-left:10px;\"><span class=\"glyphicon glyphicon-remove-sign\"></span><b>&nbsp;Offline</b></td>");
		}
		else
		{
			tr.append("<td style=\"color: #33cc33; padding-left:10px;\"><span class=\"glyphicon glyphicon-ok-sign\"></span><b>&nbsp;Online</b></td>");
		}
		$('#tableMachineStatus' + machineIdx).append(tr);
		
		var tr = $('<tr/>');
		tr.append("<td style=\"padding-left:10px;\">Disk Usage:</td>");
		if (data["disk_usage"] > 90)
		{
			tr.append("<td style=\"color: red; padding-left:10px;\"><span class=\"glyphicon glyphicon-remove-sign\"></span><b>&nbsp;" + data["disk_usage"] + "%</b></td>");
		}
		else if (data["disk_usage"] > 70)
		{
			tr.append("<td style=\"color: #ffcc00; padding-left:10px;\"><span class=\"glyphicon glyphicon-alert\"></span><b>&nbsp;" + data["disk_usage"] + "%</b></td>");
		}
		else
		{
			tr.append("<td style=\"color: #33cc33; padding-left:10px;\"><span class=\"glyphicon glyphicon-ok-sign\"></span><b>&nbsp;" + data["disk_usage"] + "%</b></td>");
		}
		$('#tableMachineStatus' + machineIdx).append(tr);

		$.getJSON(
			'/status/' + hostname + '/status.json', 
			{_: new Date().getTime()},
			callbackStatus(machineIdx));
	};							
	
}

function callbackStatus(machineIdx)
{
	return function(data) {
		var tr;
		tr = $('<tr/>');
		tr.append('<td style="padding-left:10px;">Last run:</td>');
		tr.append('<td style="padding-left:10px;"><b>&nbsp;' + data[0]["time"].substring(0, 10) + '</b>&nbsp;<button type="button" class="btn btn-info btn-xs" data-toggle="collapse" data-target="#runStatus' + machineIdx + '">Details</button></td>');
		$('#tableMachineStatus' + machineIdx).append(tr);

		tr = $('<tr/>');
		tr.append('<td style="padding-left:10px;"></td>');
		tr.append('<td style="padding-left:10px;"></td>');
		//$('#tableMachineStatus' + machineIdx).append(tr);
		
		var div = $('<div id="runStatus' + machineIdx + '" class="collapse" style="padding-top:10px"></div>');
		div.append('<table id="tableEvents' + machineIdx + '"></table>');
		$('#container' + machineIdx).append(div);

		
		for (var i = (data.length -1); i >= 0 ; i--) {
			tr = $('<tr/>');
			$('#tableEvents' + machineIdx).append(tr);
			switch(data[i]["type"]) {
				case "ERROR":
					tr.append("<td style=\"color: red; vertical-align:top\"><span class=\"glyphicon glyphicon-remove-sign\"></span></td>");
					break;
				case "WARNING":
					tr.append("<td style=\"color: #ffcc00;vertical-align:top\"><span class=\"glyphicon glyphicon-alert\"></span></td>");
					break;
				case "OK":
					tr.append("<td style=\"color: #33cc33; vertical-align:top;\"><span class=\"glyphicon glyphicon-ok-sign\"></span></td>");
					break;
				default:
					tr.append(data[i]["type"]);
			}
			
			tr.append("<td>&nbsp;" + data[i]["time"].substring(11) + " - " + data[i]["message"] + "</td>");
			$('#tableEvents' + machineIdx).append(tr);
		}
	};
}			


function loadMachines() {
	$.getJSON('/status/machines.json', {_: new Date().getTime()}, function(machines) {
	
		for (var j = 0; j < machines.length ; j++) {
		
			var hostname = machines[j]["hostname"];
			
			var div = $('<div class="well" id="container' + j + '"></div>');
			$('#status').append(div);
			
			$('#container' + j).append("<h4><b>System:</b> " + hostname + "</h4><table id=\"tableMachineStatus" + j + "\"></table>");

			if (machines[j]["description"])
			{
				var tr;
				tr = $('<tr/>');
				tr.append("<td style=\"padding-left:10px;\">Description:</td>");
				tr.append("<td style=\"padding-left:10px;\"><b>&nbsp;" + machines[j]["description"] + "</b></td>");
				$('#tableMachineStatus' + j).append(tr);
			}
			if (machines[j]["operator"])
			{
				var tr;
				tr = $('<tr/>');
				tr.append("<td style=\"padding-left:10px;\">Operator:</td>");
				tr.append("<td style=\"padding-left:10px;\"><b>&nbsp;" + machines[j]["operator"] + "</b></td>");
				$('#tableMachineStatus' + j).append(tr);
			}
			
			$.getJSON(
				'/status/' + hostname + '/heartbeat.json',
				{_: new Date().getTime()},
				callbackHeartbeat(j, hostname));
		}
	});
}

$("#btn_refresh").on('click', function() {

	$('#status').html("");
	loadMachines();

});

loadMachines();
