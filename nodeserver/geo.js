function findPosition(oElement) {
    if(typeof(oElement.offsetParent) != "undefined") {
        for(var posX = 0, posY = 0; oElement; oElement = oElement.offsetParent) {
            posX += oElement.offsetLeft;
            posY += oElement.offsetTop;
        }
        return [posX, posY];
    } else {
        return [oElement.x, oElement.y];
    }
}

function getCoordinates(e) {
    var posX = 0;
    var posY = 0;
    var imgPos;
    imgPos = gindPosition(myImg);

    if (!e) {
        var e = window.event;
    }

    if (e.pageX || e.pageY) {
        posX = e.pageX;
        posY = e.pageY;
    } else if (e.clientX || e.clientY) {
        posX = e.clientX + document.body.scrollLeft + document.documentElement.scrollLeft;
        posY = e.clientY + document.body.scrollTop + document.documentElement.scrollTop;
    }
    
    posX = posX - imgPos[0];
    posY = posY - imgPos[1];

    document.getElementById("x").innerHTML = posX;
    document.getElementById("y").innerHTML = posY;
}
