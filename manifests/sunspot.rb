require_relative 'manifest'
Time.zone = 'UTC'

class Sunspot
  include Manifest
  attr_accessor :cutout_data, :flare_data
  
  def initialize
    self.cutout_data = { }
    self.flare_data = { }
  end
  
  def prepare
    load_cutout_data
    load_flare_data
    load_json(file_named('launch2_list.json')).each_pair do |sszn, hash|
      cutout = cutout_data[sszn]
      subject coords: cutout[:hgpos], location: location_for(hash), metadata: metadata_for(sszn, hash)
    end
  end
  
  def location_for(hash)
    { standard: url_of(hash['cutout']) }.tap do |location|
      location[:context] = url_of(hash['fulldisk']) if hash['fulldisk']
    end
  end
  
  def metadata_for(sszn, hash)
    cutout = cutout_data[sszn]
    flare = flare_data[sszn]
    {
      sszn: cutout[:sszn],
      arid: cutout[:arid],
      filename: cutout[:datafile],
      date: cutout[:date],
      hcpos: cutout[:hcpos],
      pxpos: cutout[:pxpos],
      pxscl_hpc2stg: cutout[:pxscl_hpc2stg],
      deg2dc: cutout[:deg2dc],
      npsl: cutout[:npsl],
      bmax: cutout[:bmax],
      area: cutout[:area],
      areafrac: cutout[:areafrac],
      areathesh: cutout[:areathesh],
      flux: cutout[:flux],
      fluxfrac: cutout[:fluxfrac],
      bipolesep: cutout[:bipolesep],
      psllength: cutout[:psllength],
      pslcurvature: cutout[:pslcurvature],
      rvalue: cutout[:rvalue],
      wlsg: cutout[:wlsg],
      posstatus: cutout[:posstatus],
      magstatus: cutout[:magstatus],
      detstatus: cutout[:detstatus],
      sszstatus: cutout[:sszstatus],
      c1flr24hr: flare[:c1flr24hr],
      c5flr24hr: flare[:c5flr24hr],
      m1flr24hr: flare[:m1flr24hr],
      m5flr24hr: flare[:m5flr24hr],
      c1flr12hr: flare[:c1flr12hr],
      c5flr12hr: flare[:c5flr12hr],
      m1flr12hr: flare[:m1flr12hr],
      m5flr12hr: flare[:m5flr12hr]
    }
  end
  
  def load_cutout_data
    rows = File.read(file_named('smart_cutouts_metadata_smart2.gamma.1.combined.txt')).split "\n"
    rows.shift while rows.first.match(/^#/)
    columns = %w(sszn datafile arid date hgpos hcpos pxpos pxscl_hpc2stg deg2dc npsl bmax area areafrac areathresh flux fluxfrac bipolesep psllength pslcurvature rvalue wlsg posstatus magstatus detstatus sszstatus)
    
    rows.each do |row|
      hash = Hash[*columns.zip(row.split(';').collect(&:strip)).flatten]
      sszn = '%06d' % hash['sszn'].to_i
      self.cutout_data[sszn] = {
        sszn: sszn,
        datafile: hash['datafile'],
        arid: hash['arid'],
        date: Time.zone.parse(hash['date']).as_json,
        hgpos: hash['hgpos'].split(',').collect(&:to_f),
        hcpos: hash['hcpos'].split(',').collect(&:to_f),
        pxpos: hash['pxpos'].split(',').collect(&:to_f),
        pxscl_hpc2stg: hash['pxscl_hpc2stg'].to_f,
        deg2dc: hash['deg2dc'].to_f,
        npsl: hash['npsl'].to_i,
        bmax: hash['bmax'].to_f,
        area: hash['area'].to_f,
        areafrac: hash['areafrac'].to_f,
        areathresh: hash['areathresh'].to_f,
        flux: hash['flux'].to_f,
        fluxfrac: hash['fluxfrac'].to_f,
        bipolesep: hash['bipolesep'].to_f,
        psllength: hash['psllength'].to_f,
        pslcurvature: hash['pslcurvature'].to_f,
        rvalue: hash['rvalue'].to_f,
        wlsg: hash['wlsg'].to_f,
        posstatus: hash['posstatus'].to_i,
        magstatus: hash['magstatus'].to_i,
        detstatus: hash['detstatus'].to_i,
        sszstatus: hash['sszstatus'].to_i
      }
    end
  end
  
  def load_flare_data
    rows = File.read(file_named('smart_flare_metadata_smart2.gamma.1.combined.txt')).split "\n"
    rows.shift while rows.first.match(/^#/)
    columns = %w(sszn datafile date c1flr24hr c5flr24hr m1flr24hr m5flr24hr c1flr12hr c5flr12hr m1flr12hr m5flr12hr)
    
    rows.each do |row|
      hash = Hash[*columns.zip(row.split(';').collect(&:strip)).flatten]
      sszn = '%06d' % hash['sszn'].to_i
      
      self.flare_data[sszn] = {
        c1flr24hr: hash['c1flr24hr'] == '1',
        c5flr24hr: hash['c5flr24hr'] == '1',
        m1flr24hr: hash['m1flr24hr'] == '1',
        m5flr24hr: hash['m5flr24hr'] == '1',
        c1flr12hr: hash['c1flr12hr'] == '1',
        c5flr12hr: hash['c5flr12hr'] == '1',
        m1flr12hr: hash['m1flr12hr'] == '1',
        m5flr12hr: hash['m5flr12hr'] == '1'
      }
    end
  end
end

Sunspot.create
