const img_now = new Date().getTime();
const img_timestamp = `${Math.floor(img_now / 60000)}`;

if ( $("#operator_email").length ) {
	
	var operator = '&#109;&#97;&#105;&#108;&#116;&#111;&#58;&#106;&#105;&#114;&#105;&#95;&#114;&#105;&#99;&#104;&#116;&#101;&#114;&#64;&#104;&#111;&#116;&#109;&#97;&#105;&#108;&#46;&#99;&#111;&#109;';
	var href = $('<div>').html(operator).text();
	$("#operator_email").attr('href', href);
}

if ( $("#modal_disclaimer").length ) {
	$('#modal_disclaimer').load('disclaimer_body.html');
}
