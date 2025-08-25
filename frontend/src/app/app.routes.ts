import { Routes } from '@angular/router';
import { HomeComponent } from './components/home/home.component';
import { QueryDbComponent } from './components/query-db/query-db.component';
import { UploadImageComponent } from './components/upload-image/upload-image.component';

export const routes: Routes = [
    { path: "", component: HomeComponent },
    { path: "query-db", component: QueryDbComponent },
    { path: 'upload-image', component: UploadImageComponent },
    { path: "**", redirectTo: '/' }
];
