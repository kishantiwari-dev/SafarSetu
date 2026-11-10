package in.safarsetu.backend.exception;

import in.safarsetu.backend.dto.ApiError;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class ApiExceptionHandler {
    @ExceptionHandler(ApiException.class)
    ResponseEntity<ApiError> api(ApiException ex,HttpServletRequest request){return response(ex.getStatus(),ex.getMessage(),request,Map.of());}
    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiError> validation(MethodArgumentNotValidException ex,HttpServletRequest request){
        Map<String,String> fields=new LinkedHashMap<>();ex.getBindingResult().getFieldErrors().forEach(e->fields.putIfAbsent(e.getField(),e.getDefaultMessage()));
        return response(HttpStatus.BAD_REQUEST,"Request validation failed",request,fields);
    }
    @ExceptionHandler(ConstraintViolationException.class)
    ResponseEntity<ApiError> constraint(ConstraintViolationException ex,HttpServletRequest request){return response(HttpStatus.BAD_REQUEST,"Request validation failed",request,Map.of("parameter","One or more request parameters are invalid"));}
    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<ApiError> integrity(DataIntegrityViolationException ex,HttpServletRequest request){return response(HttpStatus.CONFLICT,"The request conflicts with existing data",request,Map.of());}
    @ExceptionHandler(DataAccessException.class)
    ResponseEntity<ApiError> databaseUnavailable(DataAccessException ex,HttpServletRequest request){return response(HttpStatus.SERVICE_UNAVAILABLE,"The database is temporarily unavailable",request,Map.of());}
    @ExceptionHandler({MissingServletRequestParameterException.class,MethodArgumentTypeMismatchException.class,HttpMessageNotReadableException.class})
    ResponseEntity<ApiError> malformed(Exception ex,HttpServletRequest request){return response(HttpStatus.BAD_REQUEST,"Request parameters or JSON are invalid",request,Map.of());}
    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<ApiError> missingPath(NoResourceFoundException ex,HttpServletRequest request){return response(HttpStatus.NOT_FOUND,"API resource not found",request,Map.of());}
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    ResponseEntity<ApiError> method(HttpRequestMethodNotSupportedException ex,HttpServletRequest request){return response(HttpStatus.METHOD_NOT_ALLOWED,"HTTP method is not supported for this path",request,Map.of());}
    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiError> unexpected(Exception ex,HttpServletRequest request){return response(HttpStatus.INTERNAL_SERVER_ERROR,"An unexpected server error occurred",request,Map.of());}
    private ResponseEntity<ApiError> response(HttpStatus status,String message,HttpServletRequest request,Map<String,String> fields){
        return ResponseEntity.status(status).body(new ApiError(Instant.now(),status.value(),status.getReasonPhrase(),message,request.getRequestURI(),fields));
    }
}
