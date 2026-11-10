package in.safarsetu.backend.entity;

import jakarta.persistence.*;

@Entity @Table(name="routes")
public class Route {
    @Id @Column(length=32) private String id;
    @Column(nullable=false,length=120) private String name;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private DataOrigin dataOrigin;
    @Column(nullable=false) private boolean active;
    protected Route() {}
    public Route(String id,String name,DataOrigin dataOrigin,boolean active){this.id=id;this.name=name;this.dataOrigin=dataOrigin;this.active=active;}
    public String getId(){return id;} public String getName(){return name;} public DataOrigin getDataOrigin(){return dataOrigin;} public boolean isActive(){return active;}
}
