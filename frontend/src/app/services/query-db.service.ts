import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class QueryDbService {
  private carsUrl = 'api/cars';
  private licensePlatesUrl = 'api/licensePlates';

  constructor(private http: HttpClient) {}

  getAllCarsInfo(): Observable<any> {
    return this.http.get<any>(this.carsUrl);
  }

  getAllLicensePlates(): string[] {
    // For simplicity, assuming this returns a static list
    return ['123ABC', '456DEF', '789GHI'];
  }

  queryCars(filters: any): Observable<any[]> {
    return this.http.post<any[]>(`${this.carsUrl}/query`, filters);
  }
}