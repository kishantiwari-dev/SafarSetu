package in.safarsetu.backend.dto;
import java.time.Instant;
public record LocationDto(String busId,double latitude,double longitude,Instant recordedAt,String dataOrigin,boolean stale,String freshnessStatus) {}
