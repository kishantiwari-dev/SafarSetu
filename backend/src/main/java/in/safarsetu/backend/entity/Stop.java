package in.safarsetu.backend.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Check;

@Entity @Table(name="stops") @Check(constraints="latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180")
public class Stop {
    @Id @Column(length=40) private String id;
    @Column(nullable=false,length=140) private String name;
    @Column(nullable=false) private double latitude;
    @Column(nullable=false) private double longitude;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private VerificationStatus verificationStatus;
    protected Stop() {}
    public Stop(String id,String name,double latitude,double longitude,VerificationStatus verificationStatus){this.id=id;this.name=name;this.latitude=latitude;this.longitude=longitude;this.verificationStatus=verificationStatus;}
    public String getId(){return id;} public String getName(){return name;} public double getLatitude(){return latitude;} public double getLongitude(){return longitude;} public VerificationStatus getVerificationStatus(){return verificationStatus;}
}
