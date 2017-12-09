require 'nokogiri'
require 'sqlite3'
require 'net/http'
require 'singleton'
require 'attr_extras'

Object.class_eval do
  unless method_defined?(:presence)
    define_method(:presence) do
      nil? || empty? ? nil : self
    end
  end
end

class Database
  include Singleton

  def connection
    @connection ||= SQLite3::Database.new(database_path)
  end

  def database_path
    @database_path ||= File.join(File.dirname(__FILE__), 'database')
  end
end

class Referentiable
  attr_reader_initialize :id, :nombre

  def self.find(id)
    sql = "select nombre from #{table} where id=#{id}"
    row = Database.instance.connection.get_first_row(sql)
    new(id, row[0])
  end
end

class Nucleo < Referentiable
  def self.table
    "nucleos"
  end

  def self.all
    sql = "select id, nombre from nucleos"
    Database.instance.connection.execute(sql).map do |row|
      Nucleo.new(row[0], row[1])
    end
  end

  def estaciones
    sql = <<-SQL
    select id, nombre
    from estaciones
    where nucleo_id=#{id}
    SQL
    Database.instance.connection.execute(sql).map do |row|
      Estacion.new(row[0], row[1])
    end
  end
end

class Estacion < Referentiable
  def self.table
    "estaciones"
  end

  def nucleo
    sql = <<-SQL
      select nucleos.id, nucleos.nombre
      from nucleos, estaciones
      where estaciones.id=#{id}
      and estaciones.nucleo_id=nucleos.id
    SQL
    row = Database.instance.connection.get_first_row(sql)
    Nucleo.new(row[0], row[1])
  end

  def self.all(nucleo)
    sql = <<-SQL
      select id, nombre
      from estaciones
      where nucleo_id=#{nucleo.id}
      order by nombre asc
    SQL
    Database.instance.connection.execute(sql).map do |row|
      Estacion.new(row[0], row[1])
    end
  end
end

class ItinerarioSimple
  attr_accessor_initialize :linea, :hora_origen, :hora_destino
end

class ItinerarioDoble
  attr_accessor_initialize :linea_1, :hora_origen_1, :hora_destino_1, :linea_2, :hora_origen_2, :hora_destino_2
end

class Horario
  attr_reader_initialize :origen, :destino, [ :hora_origen, :hora_destino, :date ]

  def horas
    @horas ||= parse_page
  end

  def hora_origen
    @hora_origen ||= 0
  end

  def hora_destino
    @hora_destino ||= 26
  end

  def date
    @date ||= Date.today
  end

  def page
    @page ||= Nokogiri::HTML(Net::HTTP.get(uri))
  end

  def uri
    URI.parse("http://horarios.renfe.com/#{params}")
  end

  def params
    "cer/hjcer310.jsp?&f1=&df=#{date.strftime("%Y%m%d")}&TXTInfo=&hd=#{hora_destino}&d=#{destino.id}&i=s&cp=NO&nucleo=#{origen.nucleo.id}&o=#{origen.id}&ho=#{hora_origen}"
  end

  def parse_sin_transbordo
    table.css('tr')[1..-1].map do |tr|
      row = tr.css('td').map(&:text).map(&:strip)
      linea = row[0]
      hora_origen = row[2]
      hora_destino = row[3]
      ItinerarioSimple.new(linea, hora_origen, hora_destino)
    end
  end

  def parse_con_transbordo
    prev = nil
    table.css('tr')[4..-1].map do |tr|
      row = tr.css('td').map(&:text).map(&:strip)
      linea_1        = row[0].presence || prev && prev[0]
      hora_origen_1  = row[2].presence || prev && prev[2]
      hora_destino_1 = row[3].presence || prev && prev[3]
      linea_2        = row[5].presence || prev && prev[5]
      hora_origen_2  = row[4].presence || prev && prev[4]
      hora_destino_2 = row[7].presence || prev && prev[7]
      prev = row
      ItinerarioDoble.new(linea_1, hora_origen_1, hora_destino_1, linea_2, hora_origen_2, hora_destino_2)
    end
  end

  def parse_page
    if transbordo?
      parse_con_transbordo
    else
      parse_sin_transbordo
    end
  end

  def transbordo?
    table.css('tr')[0].css('td').size > 5
  end

  def table
    page.css('table')[0]
  end
end
