import urllib2
from xml.dom import minidom

RENFE_NUCLEOS = 'http://renfe.mobi/renfev2/ciudades_cercanias.do'
RENFE_ESTACIONES = 'http://renfe.mobi/renfev2/hora_ga_cercanias.do'

def get_list_nucleo_ciudad():
    page = urllib2.urlopen(RENFE_NUCLEOS)
    content = page.read()
    dom = minidom.parseString(content)
    links = dom.getElementsByTagName('a')
    lnc = []
    for link in links:
        url = link.attributes['href'].nodeValue
        l = url.split('&')
        if len(l) >= 3:
            ciudad = l[1].split('ciudad=')[1].split('\n')[0]
            nucleo = l[2].split('nucleo=')[1]
            lnc.append({
                'nucleo': nucleo,
                'ciudad': ciudad
                })
    return lnc

def get_list_id_estacion(nucleo, ciudad):
    url = RENFE_ESTACIONES + "?nucleo=%s&ciudad=%s" % (nucleo, ciudad)
    page = urllib2.urlopen(url)
    content = page.read()
    dom = minidom.parseString(content)
    selects = dom.getElementsByTagName('select')
    le = []
    for select in selects:
        if select.attributes['name'].nodeValue == 'o':
            for e in select.childNodes:
                id_estacion = e.attributes['value'].nodeValue.encode('utf-8')
                estacion = e.firstChild.nodeValue.encode('utf-8')
                le.append({
                    'id': id_estacion,
                    'estacion': estacion
                    })
    return le

if __name__ == '__main__':
    lnc = get_list_nucleo_ciudad()
    for nc in lnc:
        print nc['nucleo'], nc['ciudad']
        le = get_list_id_estacion(nc['nucleo'], nc['ciudad'])
        for e in le:
            print e['id'], e['estacion']
        print
