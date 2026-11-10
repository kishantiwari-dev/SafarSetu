package in.safarsetu.backend.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="occupancy_snapshots",indexes=@Index(columnList="bus_id,snapshot_at"))
public class OccupancySnapshot {
    @Id @Column(length=64) private String id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="bus_id") private Bus bus;
    @Column(name="snapshot_at",nullable=false) private Instant snapshotAt;
    @Column(name="estimated_onboard",nullable=false) private int estimatedOnboard;
    private Integer seatedPassengers;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private DataQuality dataQuality;
    @Column(length=300) private String assumptions;
    protected OccupancySnapshot() {}
    public OccupancySnapshot(String id,Bus bus,Instant snapshotAt,int estimatedOnboard,Integer seatedPassengers,DataQuality dataQuality,String assumptions){this.id=id;this.bus=bus;this.snapshotAt=snapshotAt;this.estimatedOnboard=estimatedOnboard;this.seatedPassengers=seatedPassengers;this.dataQuality=dataQuality;this.assumptions=assumptions;}
    public String getId(){return id;} public Bus getBus(){return bus;} public Instant getSnapshotAt(){return snapshotAt;} public int getEstimatedOnboard(){return estimatedOnboard;} public Integer getSeatedPassengers(){return seatedPassengers;} public DataQuality getDataQuality(){return dataQuality;} public String getAssumptions(){return assumptions;}
}
