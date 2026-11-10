package in.safarsetu.backend.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Check;
import java.time.Instant;

@Entity @Table(name="bus_locations",indexes=@Index(columnList="bus_id,recorded_at")) @Check(constraints="latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180")
public class BusLocation {
    @Id @Column(length=64) private String id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="bus_id") private Bus bus;
    @Column(nullable=false) private double latitude;
    @Column(nullable=false) private double longitude;
    @Column(name="recorded_at",nullable=false) private Instant recordedAt;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private DataOrigin dataOrigin;
    protected BusLocation() {}
    public BusLocation(String id,Bus bus,double latitude,double longitude,Instant recordedAt,DataOrigin dataOrigin){this.id=id;this.bus=bus;this.latitude=latitude;this.longitude=longitude;this.recordedAt=recordedAt;this.dataOrigin=dataOrigin;}
    public String getId(){return id;} public Bus getBus(){return bus;} public double getLatitude(){return latitude;} public double getLongitude(){return longitude;} public Instant getRecordedAt(){return recordedAt;} public DataOrigin getDataOrigin(){return dataOrigin;}
}
